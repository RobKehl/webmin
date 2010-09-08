#!/usr/local/bin/perl
# Save user and group database

require './acl-lib.pl';
$access{'pass'} || &error($text{'sql_ecannot'});
&get_miniserv_config(\%miniserv);
&ReadParse();
&error_setup($text{'sql_err'});
$p = $in{'proto'};

# Parse inputs
if ($p eq 'mysql' || $p eq 'postgresql' || $p eq 'ldap') {
	gethostbyname($in{$p."_host"}) ||
	  $in{$p."_host"} =~ /^(\S+):(\d+)$/ && gethostbyname($1) ||
	    &error($text{'sql_ehost'});
	$in{$p."_user"} =~ /^\S+$/ || &error($text{'sql_euser'});
	$in{$p."_pass"} =~ /^\S*$/ || &error($text{'sql_epass'});
	$host = $in{$p."_host"};
	$user = $in{$p."_user"};
	$pass = $in{$p."_pass"};
	}
if ($p eq 'mysql' || $p eq 'postgresql') {
	$in{$p."_db"} =~ /^\S+$/ || &error($text{'sql_edb'});
	$prefix = $in{$p."_db"};
	}
elsif ($p eq 'ldap') {
	$in{$p."_prefix"} =~ /^\S+$/ || &error($text{'sql_eprefix'});
	$in{$p."_prefix"} =~ /=/ || &error($text{'sql_eprefix2'});
	$prefix = $in{$p."_prefix"};
	}

# Create and test connection string
if ($p) {
	$str = &join_userdb_string($p, $user, $pass, $host,
				   $prefix, $args);
	$err = &validate_userdb($str, 1);
	&error($err) if ($err);
	}

&lock_file($ENV{'MINISERV_CONFIG'});
$miniserv{'userdb'} = $str;
$miniserv{'userdb_addto'} = $in{'addto'};
&put_miniserv_config(\%miniserv);
&unlock_file($ENV{'MINISERV_CONFIG'});
&reload_miniserv();
&webmin_log("sql");

# Make sure tables exist
$err = &validate_userdb($str, 0);
if ($err) {
	&ui_print_header(undef, $text{'sql_title2'}, "");

	print &text('sql_tableerr', $err),"<p>\n";
	print $text{'sql_tableerr2'},"<p>\n";
	print &ui_form_start("maketables.cgi");
	print &ui_form_end([ [ undef, $text{'sql_make'} ] ]);

	print &ui_table_start(undef, undef, 2);
	foreach $sql (&userdb_table_sql($str)) {
		print &ui_table_row(undef,
			"<pre>".&html_escape($sql)."</pre>", 2);
		}
	print &ui_table_end();

	&ui_print_footer("", $text{'index_return'});
	}
else {
	&redirect("");
	}

