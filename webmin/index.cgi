#!/usr/local/bin/perl
# index.cgi
# Display a table of icons for different types of webmin configuration

require './webmin-lib.pl';
$ver = &get_webmin_version();
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
	undef, undef, undef, &text('index_version', $ver));
%access = &get_module_acl();

@wlinks = ( "edit_access.cgi", "edit_bind.cgi", "edit_log.cgi",
	    "edit_proxy.cgi", "edit_ui.cgi", "edit_mods.cgi",
	    "edit_os.cgi", "edit_lang.cgi", "edit_startpage.cgi",
	    "edit_upgrade.cgi", "edit_session.cgi", "edit_assignment.cgi",
	    "edit_categories.cgi", "edit_descs.cgi", "edit_themes.cgi",
	    "edit_referers.cgi", "edit_anon.cgi", "edit_lock.cgi",
	    "edit_mobile.cgi", "edit_advanced.cgi" );
@wtitles = ( $text{'access_title'}, $text{'bind_title'},
	     $text{'log_title'}, $text{'proxy_title'},
	     $text{'ui_title'}, $text{'mods_title'},
	     $text{'os_title'}, $text{'lang_title'},
	     $text{'startpage_title'}, $text{'upgrade_title'},
	     $text{'session_title'}, $text{'assignment_title'},
	     $text{'categories_title'}, $text{'descs_title'},
	     $text{'themes_title'}, $text{'referers_title'},
	     $text{'anon_title'}, $text{'lock_title'},
	     $text{'mobile_title'}, $text{'advanced_title'} );
@wicons = ( "images/access.gif", "images/bind.gif", "images/log.gif",
	    "images/proxy.gif", "images/ui.gif", "images/mods.gif",
	    "images/os.gif", "images/lang.gif", "images/startpage.gif",
            "images/upgrade.gif", "images/session.gif",
	    "images/assignment.gif", "images/categories.gif",
	    "images/descs.gif", "images/themes.gif", "images/referers.gif",
	    "images/anon.gif", "images/lock.gif", "images/mobile.gif",
	    "images/advanced.gif" );
if ($gconfig{'eazel'}) {
	push(@wlinks, "edit_syslet.cgi");
	push(@wtitles, $text{'syslet_title'});
	push(@wicons, "images/syslet.gif");
	}
push(@wlinks, "edit_ssl.cgi", "edit_ca.cgi");
push(@wtitles, $text{'ssl_title'}, $text{'ca_title'});
push(@wicons, "images/ssl.gif", "images/ca.gif");

# Hide dis-allowed pages
%allow = map { $_, 1 } split(/\s+/, $access{'allow'});
%disallow = map { $_, 1 } split(/\s+/, $access{'disallow'});
for($i=0; $i<@wlinks; $i++) {
	$wlinks[$i] =~ /edit_(\S+)\.cgi/;
	if (%allow && !$allow{$1} ||
	    $disallow{$1} ||
	    $1 eq "webmin" && $gconfig{'os_type'} eq 'windows') {
		splice(@wlinks, $i, 1);
		splice(@wtitles, $i, 1);
		splice(@wicons, $i, 1);
		$i--;
		}
	}
&icons_table(\@wlinks, \@wtitles, \@wicons);

print "<hr>\n";

print &ui_buttons_start();

if (&foreign_check("init")) {
	&foreign_require("init", "init-lib.pl");
	if ($init::init_mode eq "init" ||
	    $init::init_mode eq "win32" ||
	    $init::init_mode eq "rc") {
		$starting = &init::action_status("webmin");
		print &ui_buttons_row("bootup.cgi",
		      $text{'index_boot'},
		      $text{'index_bootmsg'}.
		      ($miniserv{'inetd'} ? "<b>$text{'index_inetd'}</b>" :
		       !$ENV{'MINISERV_CONFIG'} ? "<b>$text{'index_apache'}</b>" : ""),
		      &ui_hidden("starting", $starting),
		      &ui_radio("boot", $starting == 2 ? 1 : 0,
				[ [ 1, $text{'yes'} ],
				  [ 0, $text{'no'} ] ]));
		}
	}

if (!$miniserv{'inetd'} && $ENV{'MINISERV_CONFIG'}) {
	print &ui_buttons_row("restart.cgi",
		      $text{'index_restart'}, $text{'index_restartmsg'});
	}

if (!$config{'submitted'}) {
	print &ui_buttons_row("submit.cgi",
		      $text{'index_submit'}, $text{'index_submitmsg'});
	}

print &ui_buttons_end();

&ui_print_footer("/", $text{'index'});

