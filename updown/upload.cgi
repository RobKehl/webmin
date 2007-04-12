#!/usr/local/bin/perl
# upload.cgi
# Upload multiple files

require './updown-lib.pl';
&error_setup($text{'upload_err'});
&ReadParse(\%getin, "GET");
$upid = $getin{'id'};
&ReadParseMime($upload_max, \&read_parse_mime_callback, [ $upid ]);
$can_upload || &error($text{'upload_ecannot'});

# Validate inputs
$in{'dir'} || &error($text{'upload_edir'});
if ($can_mode != 3) {
	# User can be entered
	defined(@uinfo = getpwnam($in{'user'})) ||
		&error($text{'upload_euser'});
	&can_as_user($in{'user'}) ||
		&error(&text('upload_eucannot', $in{'user'}));
	$in{'group_def'} || defined(@ginfo = getgrnam($in{'group'})) ||
		&error($text{'upload_egroup'});
	$can_mode == 0 || $in{'group_def'} || &in_group(\@uinfo, \@ginfo) ||
		&error($text{'upload_egcannot'});
	}
else {
	# User is fixed
	if (&supports_users()) {
		@uinfo = getpwnam($remote_user);
		}
	}
for($i=0; defined($d = $in{"upload$i"}); $i++) {
	$f = $in{"upload${i}_filename"};
	$found++ if ($d && $f);
	}
$found || &error($text{'upload_enone'});
&can_write_file($in{'dir'}) ||
	&error(&text('upload_eaccess', "<tt>$in{'dir'}</tt>", $!));

# Switch to the upload user
&switch_uid_to($uinfo[2], defined(@ginfo) ? $ginfo[2] : $uinfo[3]);

# Create the directory if needed
if (!-d $in{'dir'} && $in{'mkdir'}) {
	mkdir($in{'dir'}, 0755) || &error(&text('upload_emkdir', $!));
	}

# Save the actual files
for($i=0; defined($d = $in{"upload$i"}); $i++) {
	$f = $in{"upload${i}_filename"};
	next if (!$f);
	if (-d $in{'dir'}) {
		$f =~ /([^\\\/]+)$/;
		$path = "$in{'dir'}/$1";
		}
	else {
		$path = $in{'dir'};
		}
	if (!&open_tempfile(FILE, ">$path", 1)) {
		&error(&text('upload_eopen', "<tt>$path</tt>", $!));
		}
	&print_tempfile(FILE, $d);
	&close_tempfile(FILE);
	push(@uploads, $path);

	if ($in{'zip'}) {
		local ($err, $out);
		$path =~ /^(\S*\/)/;
		local $dir = $1;
		local $qdir = quotemeta($dir);
		local $qpath = quotemeta($path);
		local @files;
		&switch_uid_back();
		if ($path =~ /\.zip$/i) {
			if (!&has_command("unzip")) {
				$err = &text('upload_ecmd', "unzip");
				}
			else {
				open(OUT, &command_as_user($uinfo[0], 0, "(cd $qdir && unzip -o $qpath)")." 2>&1 </dev/null |");
				while(<OUT>) {
					$out .= $_;
					if (/^\s*[a-z]+:\s+(.*)/) {
						push(@files, $1);
						}
					}
				close(OUT);
				$err = $out if ($?);
				}
			}
		elsif ($path =~ /\.tar$/i) {
			if (!&has_command("tar")) {
				$err = &text('upload_ecmd', "tar");
				}
			else {
				open(OUT, &command_as_user($uinfo[0], 0, "(cd $qdir && tar xvf $qpath)")." 2>&1 </dev/null |");
				while(<OUT>) {
					$out .= $_;
					if (/^(.*)/) {
						push(@files, $1);
						}
					}
				close(OUT);
				$err = $out if ($?);
				}
			}
		elsif ($path =~ /\.(tar\.gz|tgz|tar\.bz|tbz|tar\.bz2|tbz2)$/i) {
			local $zipper = $path =~ /bz(2?)$/i ? "bunzip2"
							    : "gunzip";
			if (!&has_command("tar")) {
				$err = &text('upload_ecmd', "tar");
				}
			elsif (!&has_command($zipper)) {
				$err = &text('upload_ecmd', $zipper);
				}
			else {
				open(OUT, &command_as_user($uinfo[0], 0, "(cd $qdir && $zipper -c $qpath | tar xvf -)")." 2>&1 </dev/null |");
				while(<OUT>) {
					$out .= $_;
					if (/^(.*)/) {
						push(@files, $1);
						}
					}
				close(OUT);
				$err = $out if ($?);
				}
			}
		else {
			# Doesn't look possible
			$err = $text{'upload_notcomp'};
			}
		&switch_uid_to($uinfo[2], defined(@ginfo) ? $ginfo[2] : $uinfo[3]);
		if (!$err) {
			local $j = join("<br>",
				map { "&nbsp;&nbsp;<tt>$_</tt>" } @files);
			if ($in{'zip'} == 2) {
				unlink($path);
				$ext{$path} = $text{'upload_deleted'}."<br>".$j;
				}
			else {
				$ext{$path} = $text{'upload_extracted'}."<br>".$j;
				}
			}
		else {
			$ext{$path} = &text('upload_eextract', $err);
			}
		}
	}

# Switch back to root
&switch_uid_back();

&ui_print_header(undef, $text{'upload_title'}, "");

print "<p>$text{'upload_done'}<p>\n";
foreach $u (@uploads) {
	@st = stat($u);
	print "<tt>$u</tt> ",@st ? "($st[7] bytes)" : "",
	      $ext{$u} ? " $ext{$u}" : "","<p>\n";
	}
print "<p>\n";

# Save the settings
if ($module_info{'usermin'}) {
	&lock_file("$user_module_config_directory/config");
	$userconfig{'dir'} = $in{'dir'};
	&write_file("$user_module_config_directory/config", \%userconfig);
	&unlock_file("$user_module_config_directory/config");
	}
else {
	&lock_file("$module_config_directory/config");
	$config{'dir_'.$remote_user} = $in{'dir'};
	$config{'user_'.$remote_user} = $in{'user'};
	$config{'group_'.$remote_user} = $in{'group_def'} ? undef
							   : $in{'group'};
	&write_file("$module_config_directory/config", \%config);
	&unlock_file("$module_config_directory/config");
	}

&webmin_log("upload", undef, undef, { 'uploads' => \@uploads });

&ui_print_footer("", $text{'index_return'});

