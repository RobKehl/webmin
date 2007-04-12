# bsd-lib.pl
# Functions for FreeBSD package management

use POSIX;
chop($system_arch = `uname -m`);
$package_dir = "/var/db/pkg";

# list_packages([package]*)
# Fills the array %packages with a list of all packages
sub list_packages
{
local $i = 0;
local $arg = @_ ? join(" ", map { quotemeta($_) } @_) : "-a";
&open_execute_command(PKGINFO, "pkg_info -I $arg", 1, 1);
while(<PKGINFO>) {
	if (/^(\S+)\s+(.*)/) {
		$packages{$i,'name'} = $1;
		$packages{$i,'class'} = "";
		$packages{$i,'desc'} = $2;
		$i++;
		}
	}
close(PKGINFO);
return $i;
}

# package_info(package)
# Returns an array of package information in the order
#  name, class, description, arch, version, vendor, installtime
sub package_info
{
local $qm = quotemeta($_[0]);
local $out = &backquote_command("pkg_info $qm 2>&1", 1);
return () if ($?);
local @rv = ( $_[0] );
push(@rv, "");
push(@rv, $out =~ /Description:\n([\0-\177]*\S)/i ? $1 : $text{'bsd_unknown'});
push(@rv, $system_arch);
push(@rv, $_[0] =~ /-([^\-]+)$/ ? $1 : $text{'bsd_unknown'});
push(@rv, "FreeBSD");
local @st = stat(&translate_filename("$package_dir/$_[0]"));
push(@rv, @st ? ctime($st[9]) : $text{'bsd_unknown'});
return @rv;
}

# check_files(package)
# Fills in the %files array with information about the files belonging
# to some package. Values in %files are  path type user group mode size error
sub check_files
{
local $i = 0;
local $file;
local $qm = quotemeta($_[0]);
&open_execute_command(PKGINFO, "pkg_info -L $qm", 1, 1);
while($file = <PKGINFO>) {
	$file =~ s/\r|\n//g;
	next if ($file !~ /^\//);
	local $real = &translate_filename($file);
	local @st = stat($real);
	$files{$i,'path'} = $file;
	$files{$i,'type'} = -l $real ? 3 :
			    -d $real ? 1 : 0;
	$files{$i,'user'} = getpwuid($st[4]);
	$files{$i,'group'} = getgrgid($st[5]);
	$files{$i,'mode'} = sprintf "%o", $st[2] & 07777;
	$files{$i,'size'} = $st[7];
	$files{$i,'link'} = readlink($real);
	$i++;
	}
return $i;
}

# installed_file(file)
# Given a filename, fills %file with details of the given file and returns 1.
# If the file is not known to the package system, returns 0
# Usable values in %file are  path type user group mode size packages
sub installed_file
{
local (%packages, $file, $i, @pkgin);
local $n = &list_packages();
for($i=0; $i<$n; $i++) {
	&open_execute_command(PKGINFO, "pkg_info -L $packages{$i,'name'}", 1, 1);
	while($file = <PKGINFO>) {
		$file =~ s/\r|\n//g;
		if ($file eq $_[0]) {
			# found it
			push(@pkgin, $packages{$i,'name'});
			}
		}
	close(PKGINFO);
	}
if (@pkgin) {
	local $real = &translate_filename($_[0]);
	local @st = stat($real);
	$file{'path'} = $_[0];
	$file{'type'} = -l $real ? 3 :
			-d $real ? 1 : 0;
	$file{'user'} = getpwuid($st[4]);
	$file{'group'} = getgrgid($st[5]);
	$file{'mode'} = sprintf "%o", $st[2] & 07777;
	$file{'size'} = $st[7];
	$file{'link'} = readlink($real);
	$file{'packages'} = join(" ", @pkgin);
	return 1;
	}
else {
	return 0;
	}
}

# is_package(file)
sub is_package
{
local $real = &translate_filename($_[0]);
local $qm = quotemeta($_[0]);
if (-d $_[0]) {
	# A directory .. see if it contains any tgz files
	opendir(DIR, $real);
	local @list = grep { /\.tgz$/ || /\.tbz$/ } readdir(DIR);
	closedir(DIR);
	return @list ? 1 : 0;
	}
elsif ($_[0] =~ /\*|\?/) {
	# a wildcard .. see what it matches
	local @list = glob($real);
	return @list ? 1 : 0;
	}
else {
	# just a normal file - see if it is a package
	local $cmd;
	foreach $cmd ('gunzip', 'bunzip2') {
		next if (!&has_command($cmd));
		local ($desc, $contents);
		&open_execute_command(TAR, "$cmd -c $qm | tar tf -", 1, 1);
		while(<TAR>) {
			$desc++ if (/^\+DESC/);
			$contents++ if (/^\+CONTENTS/);
			}
		close(TAR);
		return 1 if ($desc && $contents);
		}
	return 0;
	}
}

# file_packages(file)
# Returns a list of all packages in the given file, in the form
#  package description
sub file_packages
{
local $real = &translate_filename($_[0]);
local $qm = quotemeta($_[0]);
if (-d $real) {
	# Scan directory for packages
	local ($f, @rv);
	opendir(DIR, $real);
	while($f = readdir(DIR)) {
		if ($f =~ /\.tgz$/i || $f =~ /\.tbz$/i) {
			local @pkg = &file_packages("$_[0]/$f");
			push(@rv, @pkg);
			}
		}
	closedir(DIR);
	return @rv;
	}
elsif ($real =~ /\*|\?/) {
	# Expand glob of packages
	# XXX won't work in translation
	local ($f, @rv);
	foreach $f (glob($real)) {
		local @pkg = &file_packages($f);
		push(@rv, @pkg);
		}
	return @rv;
	}
else {
	# Just one file
	local $cmd;
	foreach $cmd ('gunzip', 'bunzip2') {
		next if (!&has_command($cmd));
		local $temp = &transname();
		&make_dir($temp, 0700);
		local $rv = &execute_command("cd $temp && $cmd -c $qm | tar xf - +CONTENTS +COMMENT");
		if ($rv) {
			&unlink_file($temp);
			next;
			}
		local ($comment, $name);
		&open_readfile(COMMENT, "$temp/+COMMENT");
		($comment = <COMMENT>) =~ s/\r|\n//g;
		close(COMMENT);
		&open_readfile(CONTENTS, "$temp/+CONTENTS");
		while(<CONTENTS>) {
			$name = $1 if (/^\@name\s+(\S+)/);
			}
		close(CONTENTS);
		&unlink_file($temp);
		return ( "$name $comment" );
		}
	return ( );
	}
}

# install_options(file, package)
# Outputs HTML for choosing install options
sub install_options
{
print "<tr> <td><b>$text{'bsd_scripts'}</b></td>\n";
print "<td><input type=radio name=scripts value=0 checked> $text{'yes'}\n";
print "<input type=radio name=scripts value=1> $text{'no'}</td> </tr>\n";

print "<tr> <td><b>$text{'bsd_force'}</b></td>\n";
print "<td><input type=radio name=force value=1> $text{'yes'}\n";
print "<input type=radio name=force value=0 checked> $text{'no'}</td> </tr>\n";
}

# install_package(file, package)
# Installs the package in the given file, with options from %in
sub install_package
{
local $in = $_[2] ? $_[2] : \%in;
local $args = ($in->{"scripts"} ? " -I" : "").
	      ($in->{"force"} ? " -f" : "");
local $out = &backquote_logged("pkg_add $args $_[0] 2>&1");
if ($?) {
	return "<pre>$out</pre>";
	}
return undef;
}

# install_packages(file, [&inputs])
# Installs all the packages in the given file or glob
sub install_packages
{
local $in = $_[2] ? $_[2] : \%in;
local $args = ($in->{"scripts"} ? " -I" : "").
	      ($in->{"force"} ? " -f" : "");
local $file;
if (-d $_[0]) {
	$file = "$_[0]/*.tgz";
	}
else {
	$file = $_[0];
	}
local $out = &backquote_logged("pkg_add $args $file 2>&1");
if ($?) {
	return "<pre>$out</pre>";
	}
return undef;
}

# delete_package(package)
# Totally remove some package
sub delete_package
{
local $out = &backquote_logged("pkg_delete $_[0] 2>&1");
if ($?) { return "<pre>$out</pre>"; }
return undef;
}

sub package_system
{
return &text('bsd_manager', "FreeBSD");
}

sub package_help
{
return "pkg_add pkg_info pkg_delete";
}

1;
