#!/usr/local/bin/perl
# search.cgi
# Find webmin actions

require './webminlog-lib.pl';
require 'timelocal.pl';
&ReadParse();
&error_setup($text{'search_err'});

# Parse entered time ranges
if ($in{'tall'} == 2) {
	@now = localtime(time());
	$from = timelocal(0, 0, 0, $now[3], $now[4], $now[5]);
	$to = timelocal(59, 59, 23, $now[3], $now[4], $now[5]);
	$in{'tall'} = 0;
	}
elsif ($in{'tall'} == 3) {
	@now = localtime(time()-24*60*60);
	$from = timelocal(0, 0, 0, $now[3], $now[4], $now[5]);
	$to = timelocal(59, 59, 23, $now[3], $now[4], $now[5]);
	$in{'tall'} = 0;
	}
elsif ($in{'tall'} == 0) {
	$from = &parse_time('from');
	$to = &parse_time('to');
	$to = $to ? $to + 24*60*60 - 1 : time();
	}

&ui_print_header(undef, $text{'search_title'}, "");

# Perform initial search in index
&build_log_index(\%index);
open(LOG, $webmin_logfile);
while(($id, $idx) = each %index) {
	local ($pos, $time, $user, $module, $sid) = split(/\s+/, $idx);
	if (($in{'uall'} == 1 ||
	     $in{'uall'} == 0 && $in{'user'} eq $user ||
	     $in{'uall'} == 2 && $in{'nuser'} ne $user) &&
	    ($in{'mall'} || $in{'module'} eq $module) &&
	    (!$in{'sid'} || $in{'sid'} eq $sid) &&
	    ($in{'tall'} || $from < $time && $to > $time)) {
		# Passed index check .. now look at actual log entry
		seek(LOG, $pos, 0);
		$line = <LOG>;
		$act = &parse_logline($line);

		# Check Webmin server
		next if (!$in{'wall'} && $in{'webmin'} ne $act->{'webmin'});

		# Check modified files
		if ($gconfig{'logfiles'} && !$in{'fall'}) {
			# Make sure the specified file was modified
			local $found = 0;
			foreach $d (&list_diffs($act)) {
				if ($d->{'object'} &&
				    $d->{'object'} eq $in{'file'}) {
					$found++;
					last;
					}
				}
			next if (!$found);
			}
		next if (!&can_user($act->{'user'}));
		next if (!&can_mod($act->{'module'}));
		push(@match, $act);
		}
	}
close(LOG);

# Build search description
@from = localtime($from);
@to = localtime($to);
$fromstr = sprintf "%2.2d/%s/%4.4d",
	$from[3], $text{"smonth_".($from[4]+1)}, $from[5]+1900;
$tostr = sprintf "%2.2d/%s/%4.4d",
	$to[3], $text{"smonth_".($to[4]+1)}, $to[5]+1900;
if (!$in{'mall'}) {
	%minfo = &get_module_info($in{'module'});
	}
$searchmsg = join(" ",
	$in{'uall'} == 0 ? &text('search_critu',
		 "<tt>".&html_escape($in{'user'})."</tt>") :
	$in{'uall'} == 2 ? &text('search_critnu',
		 "<tt>".&html_escape($in{'nuser'})."</tt>") : "",
	$in{'mall'} ? '' : &text('search_critm',
		 "<tt>".&html_escape($minfo{'desc'})."</tt>"),
	$in{'tall'} ? '' : 
	  $fromstr eq $tostr ? &text('search_critt2', $tostr) :
	    &text('search_critt', $fromstr, $tostr));

if (@match) {
	if ($in{'sid'}) {
		print "<b>",&text('search_sid', "<tt>$match[0]->{'user'}</tt>",
				  "<tt>$in{'sid'}</tt>")," ..</b><p>\n";
		}
	elsif ($in{'uall'} == 1 && $in{'mall'} && $in{'tall'}) {
		print "<b>$text{'search_critall'} ..</b><p>\n";
		}
	else {
		@from = localtime($from); @to = localtime($to);
		$fromstr = sprintf "%2.2d/%s/%4.4d",
			$from[3], $text{"smonth_".($from[4]+1)}, $from[5]+1900;
		$tostr = sprintf "%2.2d/%s/%4.4d",
			$to[3], $text{"smonth_".($to[4]+1)}, $to[5]+1900;
		%minfo = &get_module_info($in{'module'}) if (!$in{'mall'});
		print "<b>$text{'search_crit'} $searchmsg ...</b><p>\n";
		}
	print &ui_columns_start(
		[ $text{'search_action'},
		  $text{'search_module'},
		  $text{'search_user'},
		  $text{'search_host'},
		  $config{'host_search'} ? ( $text{'search_webmin'} ) : ( ),
		  $text{'search_date'},
		  $text{'search_time'} ], "100");
	foreach $act (sort { $b->{'time'} <=> $a->{'time'} } @match) {
		local @tm = localtime($act->{'time'});
		local $m = $act->{'module'};
		local $d;
		$minfo = $minfo_cache{$m};
		if (!$minfo) {
			# first time seeing module ..
			local %minfo = &get_module_info($m);
			$minfo = $minfo_cache{$m} = \%minfo;
			if (-r "../$m/log_parser.pl") {
				&foreign_require($m, "log_parser.pl");
				$parser{$m}++;
				}
			}

		local @cols;
		$d = &foreign_call($m, "parse_webmin_log",
				  $act->{'user'}, $act->{'script'},
				  $act->{'action'}, $act->{'type'},
				  $act->{'object'}, $act->{'param'})
					if ($parser{$m});
		local $desc;
		if ($d) {
			$desc = $d;
			}
		elsif ($act->{'action'} eq '_config_') {
			$desc = $text{'search_config'};
			}
		else {
			$desc = sprintf "%s %s %s\n",
				$act->{'action'},
				$act->{'type'} ? $act->{'type'} : '',
				$act->{'object'} ? $act->{'object'} : '';
			}
		push(@cols, "<a href='view.cgi?id=$act->{'id'}".
		      "&return=".&urlize($in{'return'}).
		      "&returndesc=".&urlize($in{'returndesc'}).
		      "'>$desc</a>");
		push(@cols, $minfo->{'desc'}, $act->{'user'}, $act->{'ip'});
		if ($config{'host_search'}) {
			push(@cols, $act->{'webmin'});
			}
		push(@cols, split(/\s+/, &make_date($act->{'time'})));
		print &ui_columns_row(\@cols);
		}
	print &ui_columns_end();
	}
else {
	# Tell the user that nothing matches
	print "<p><b>$text{'search_none2'} $searchmsg.</b><p>\n";
	}

if ($in{'return'}) {
	&ui_print_footer($in{'return'}, $in{'returndesc'});
	}
else {
	&ui_print_footer("", $text{'index_return'});
	}

sub parse_time
{
local $d = $in{"$_[0]_d"};
local $m = $in{"$_[0]_m"};
local $y = $in{"$_[0]_y"};
return 0 if (!$d && !$y);
local $rv;
eval { $rv = timelocal(0, 0, 0, $d, $m, $y-1900) };
&error($text{'search_etime'}) if ($@);
return $rv;
}
