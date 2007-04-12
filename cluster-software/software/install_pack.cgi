#!/usr/local/bin/perl
# install_pack.cgi
# Install a package from some source

require './software-lib.pl';
if ($ENV{REQUEST_METHOD} eq "POST") { &ReadParseMime(); }
else { &ReadParse(); $no_upload = 1; }
&error_setup($text{'install_err'});

if ($in{source} >= 2) {
	&ui_print_unbuffered_header(undef, $text{'install_title'}, "", "install");
	}
else {
	&ui_print_header(undef, $text{'install_title'}, "", "install");
	}

if ($in{source} == 0) {
	# installing from local file (or maybe directory)
	if (!$in{'local'})
		{ &install_error($text{'install_elocal'}); }
	if (!-r $in{'local'} && !-d $in{'local'} && $in{'local'} !~ /\*|\?/)
		{ &install_error(&text('install_elocal2', $in{'local'})); }
	$source = $in{'local'};
	$pfile = $in{'local'};
	$need_unlink = 0;
	}
elsif ($in{source} == 1) {
	# installing from upload .. store file in temp location
	if ($no_upload) {
		&install_error($text{'install_eupload'});
		}
	$in{'upload_filename'} =~ /([^\/\\]+$)/;
	$pfile = &tempname("$1");
	&open_tempfile(PFILE, ">$pfile", 0, 1);
	&print_tempfile(PFILE, $in{'upload'});
	&close_tempfile(PFILE);
	$source = $in{'upload_filename'};
	$need_unlink = 1;
	}
elsif ($in{source} == 2) {
	# installing from URL.. store downloaded file in temp location
	$in{'url'} = &convert_osdn_url($in{'url'});
	$in{'url'} =~ /\/([^\/]+)\/*$/;
	$pfile = &tempname("$1");
	local $error;
	$progress_callback_url = $in{'url'};
	if ($in{'url'} =~ /^(http|https):\/\/([^\/]+)(\/.*)$/) {
		# Make a HTTP request
		$ssl = $1 eq 'https';
		$host = $2; $page = $3; $port = $ssl ? 443 : 80;
		if ($host =~ /^(.*):(\d+)$/) { $host = $1; $port = $2; }
		&http_download($host, $port, $page, $pfile, \$error,
			       \&progress_callback, $ssl);
		}
	elsif ($in{'url'} =~ /^ftp:\/\/([^\/]+)(:21)?(\/.*)$/) {
		$host = $1; $file = $3;
		&ftp_download($host, $file, $pfile, \$error,
			      \&progress_callback);
		}
	else {
		&install_error(&text('install_eurl', $in{'url'}));
		}
	&install_error($error) if ($error);
	$source = $in{'url'};
	$need_unlink = 1;
	}
elsif ($in{'source'} == 3) {
	# installing from some update system
	@packs = &update_system_install($in{'update'}, \%in);

	print "<hr>\n" if (@packs);
	foreach $p (@packs) {
		local @pinfo = &show_package_info($p);
		}
	&webmin_log($config{'update_system'}, "install", undef,
		    { 'packages' => \@packs } ) if (@packs);

	if ($in{'return'}) {
		&ui_print_footer($in{'return'}, $in{'returndesc'});
		}
	else {
		&ui_print_footer("", $text{'index_return'});
		}
	exit;
	}

# Check validity
if (!&is_package($pfile)) {
	if (-d $pfile) {
		&install_error(&text('install_edir', &package_system()));
		}
	else {
		# attempt to uncompress
		local $unc = &uncompress_if_needed($pfile, $need_unlink);
		if ($unc ne $pfile) {
			# uncompressed ok..
			if (!&is_package($unc)) {
				&unlink_file($unc);
				&install_error(&text('install_ezip',
					     &package_system()));
				}
			$pfile = $unc;
			}
		else {
			# uncompress failed.. give up
			#unlink($pfile) if ($need_unlink);
			&install_error(&text('install_efile', &package_system()));
			}
		}
	}

# ask for package to install and install options
@rv = &file_packages($pfile);

print "<form action=do_install.cgi>\n";
print "<input type=hidden name=file value=\"$pfile\">\n";
print "<input type=hidden name=need_unlink value=\"$need_unlink\">\n";
print "<table border>\n";
print "<tr $tb> <td><b>$text{'install_header'}</b></td> </tr>\n";
print "<tr $cb> <td><table>\n";
print "<tr> <td valign=top><b>$text{'install_packs'}</b></td>\n";
print $wide_install_options ? "<td colspan=3>\n" : "<td>\n";
foreach (@rv) {
	($p, $d) = split(/\s+/, $_, 2);
	if ($d) {
		print &html_escape($d)," (",&html_escape($p),")<br>\n";
		}
	else {
		print &html_escape($p),"<br>\n";
		}
	}
&install_options($pfile, $p);
print "</table></td></tr>\n";
print "</table><input type=submit value=\"$text{'install_ok'}\"></form>\n";

&ui_print_footer("", $text{'index_return'});

sub install_error
{
print "<br><b>$whatfailed : $_[0]</b> <p>\n";
&ui_print_footer("", $text{'index_return'});
exit;
}


