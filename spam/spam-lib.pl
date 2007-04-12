# spam-lib.pl
# Common functions for parsing and editing the spamassassin config file
# XXX online help
# XXX whitelist editing?

do '../web-lib.pl';
&init_config();
do '../ui-lib.pl';

$local_cf = $config{'local_cf'};
$warn_procmail = $config{'warn_procmail'};
if ($module_info{'usermin'}) {
	# Running under Usermin, editing user's personal config file
	&switch_to_remote_user();
	&create_user_config_dirs();
	if ($local_cf !~ /^\//) {
		$local_cf = "$remote_user_info[7]/$local_cf";
		if ($local_cf =~ /^(.*)\// && !-d $1) {
			mkdir($1, 0700);
			}
		}
	}
else {
	# Running under Webmin, typically editing global config file
	%access = &get_module_acl();
	if ($access{'file'}) {
		$local_cf = $access{'file'};
		}
	if ($access{'nocheck'}) {
		$warn_procmail = 0;
		}
	}
$add_cf = !-d $local_cf ? $local_cf :
	  $module_info{'usermin'} ? "$local_cf/user_prefs" :
				    "$local_cf/local.cf";

# get_config([file])
# Return a structure containing the contents of the spamassassin config file
sub get_config
{
local @rv;
local $lnum = 0;
local $file = $_[0] || $local_cf;
if (-d $file) {
	# A directory of files - read them all
	opendir(DIR, $file);
	local @files = sort { $a cmp $b } readdir(DIR);
	closedir(DIR);
	local $f;
	foreach $f (@files) {
		if ($f =~ /\.cf$/) {
			local $add = &get_config("$file/$f");
			map { $_->{'index'} += scalar(@rv) } @$add;
			push(@rv, @$add);
			}
		}
	}
else {
	# A single file that can be read right here
	open(FILE, $file);
	while(<FILE>) {
		s/\r|\n//g;
		s/^#.*$//;
		if (/^(\S+)\s*(.*)$/) {
			local $dir = { 'name' => $1,
				       'value' => $2,
				       'index' => scalar(@rv),
				       'file' => $file,
				       'line' => $lnum };
			$dir->{'words'} = [ split(/\s+/, $dir->{'value'}) ];
			push(@rv, $dir);
			}
		$lnum++;
		}
	close(FILE);
	}
return \@rv;
}

# find(name, &config)
sub find
{
local @rv;
foreach $c (@{$_[1]}) {
	push(@rv, $c) if (lc($c->{'name'}) eq lc($_[0]));
	}
return wantarray ? @rv : $rv[0];
}

# find_value(name, &config)
sub find_value
{
local @rv = map { $_->{'value'} } &find(@_);
return wantarray ? @rv : $rv[0];
}

# save_directives(&config, name|&old, &new, valuesonly)
# Update the config file with some directives
sub save_directives
{
local @old = ref($_[1]) ? @{$_[1]} : &find($_[1], $_[0]);
local @new = $_[3] ? &make_directives($_[1], $_[2]) : @{$_[2]};
local $i;
for($i=0; $i<@old || $i<@new; $i++) {
	local $line;
	if ($new[$i]) {
		$line = $new[$i]->{'name'};
		$line .= " ".$new[$i]->{'value'} if ($new[$i]->{'value'} ne '');
		}
	if ($old[$i] && $new[$i]) {
		# Replacing a directive
		local $lref = &read_file_lines($old[$i]->{'file'});
		$lref->[$old[$i]->{'line'}] = $line;
		$_[0]->[$old[$i]->{'index'}] = $new[$i];
		}
	elsif ($old[$i]) {
		# Deleting a directive
		local $lref = &read_file_lines($old[$i]->{'file'});
		splice(@$lref, $old[$i]->{'line'}, 1);
		splice(@{$_[0]}, $old[$i]->{'index'}, 1);
		foreach $c (@{$_[0]}) {
			$c->{'line'}-- if ($c->{'line'} > $old[$i]->{'line'} &&
					   $c->{'file'} eq $old[$i]->{'file'});
			$c->{'index'}-- if ($c->{'index'} > $old[$i]->{'index'});
			}
		}
	elsif ($new[$i]) {
		# Adding a directive
		local $lref = &read_file_lines($add_cf);
		$new[$i]->{'line'} = @$lref;
		$new[$i]->{'index'} = @{$_[0]};
		push(@$lref, $line);
		push(@{$_[0]}, $new[$i]);
		}
	}
}

# make_directives(name, &values)
sub make_directives
{
return map { { 'name' => $_[0],
	       'value' => $_ } } @{$_[1]};
}

### UI functions ###

# edit_table(name, &headings, &&values, &sizes, [&convfunc], blankrows)
# Display a table of values for editing, with one blank row
sub edit_table
{
local ($h, $v);
print "<table border>\n";
print "<tr $tb>\n";
foreach $h (@{$_[1]}) {
	print "<td><b>$h</b></td>\n";
	}
print "</tr>\n";
local $i = 0;
local $cfunc = $_[4] || \&default_convfunc;
local $blanks = $_[5] || 1;
foreach $v (@{$_[2]}, map { [ ] } (1 .. $blanks)) {
	print "<tr $cb>\n";
	for($j=0; $j<@{$_[1]}; $j++) {
		print "<td>",&$cfunc($j, "$_[0]_${i}_${j}", $_[3]->[$j],
				     $v->[$j], $v),"</td>";
		}
	print "</tr>\n";
	$i++;
	}
print "</table>\n";
}

# default_convfunc(column, name, size, value)
sub default_convfunc
{
return "<input name=$_[1] size=$_[2] value='".&html_escape($_[3])."'>";
}

# parse_table(name, &parser)
# Parse the inputs from a table and return an array of results
sub parse_table
{
local ($i, @rv);
local $pfunc = $_[1] || \&default_parsefunc;
for($i=0; defined($in{"$_[0]_${i}_0"}); $i++) {
	local ($j, $v, @vals);
	for($j=0; defined($v = $in{"$_[0]_${i}_${j}"}); $j++) {
		push(@vals, $v);
		}
	local $p = &$pfunc("$_[0]_${i}", @vals);
	push(@rv, $p) if (defined($p));
	}
return @rv;
}

# default_parsefunc(rowname, value, ...)
# Returns a value or undef if empty, or calls &error if invalid
sub default_parsefunc
{
return $_[1] ? join(" ", @_[1..$#_]) : undef;
}

# start_form(cgi, header)
sub start_form
{
print "<form action=$_[0] method=post>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$_[1]</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";
}

# end_form(buttonname, buttonvalue, ...)
sub end_form
{
print "</table></td></tr></table>\n";
if (@_) {
	local $p = int(200 / scalar(@_));
	print "<table width=100%><tr>\n";
	local $i;
	for($i=0; $i<@_; $i+=2 ) {
		local $al = $i == 0 ? "align=left" :
			    $i == @_-2 ? "align=right" : "align=center";
		local $n = $_[$i] ? "name='$_[$i]'" : "";
		local $v = &html_escape($_[$i+1]);
		print "<td width=$p% $al><input type=submit $n value='$v'></td>\n";
		}
	print "</table>\n";
	}
print "</form>\n";
}

# yes_no_field(name, value, default)
sub yes_no_field
{
local $v = !$_[1] ? -1 : $_[1]->{'value'};
local $def = &find_default($_[0], $_[2]) ? $text{'yes'} : $text{'no'};
printf "<input type=radio name=$_[0] value=1 %s> %s\n",
	$v == 1 ? "checked" : "", $text{'yes'};
printf "<input type=radio name=$_[0] value=0 %s> %s\n",
	$v == 0 ? "checked" : "", $text{'no'};
printf "<input type=radio name=$_[0] value=-1 %s> %s (%s)\n",
	$v == -1 ? "checked" : "", $text{'default'}, $def;
}

# parse_yes_no(&config, name)
sub parse_yes_no
{
&save_directives($_[0], $_[1], $in{$_[1]} == 1 ? [ 1 ] :
			       $in{$_[1]} == 0 ? [ 0 ] : [ ], 1);
}

# option_field(name, value, default, &opts)
sub option_field
{
local $v = !$_[1] ? -1 : $_[1]->{'value'};
local $def = &find_default($_[0], $_[2]);
local ($defopt) = grep { $_->[0] eq $def } @{$_[3]};
print &ui_radio($_[0], $v,
		[ @{$_[3]}, [ -1, "$text{'default'} ($defopt->[1])" ] ]);
}

sub parse_option
{
&save_directives($_[0], $_[1], $in{$_[1]} == -1 ? [ ] : [ $in{$_[1]} ], 1);
}

# opt_field(name, value, size, default)
sub opt_field
{
local $def = &find_default($_[0], $_[3]) if ($_[3]);
printf "<input type=radio name=$_[0]_def value=1 %s> %s %s\n",
	$_[1] ? "" : "checked", $text{'default'}, $_[3] ? " ($def)" : "";
printf "<input type=radio name=$_[0]_def value=0 %s>\n",
	$_[1] ? "checked" : "";
printf "<input name=$_[0] size=$_[2] value='%s'>\n",
	$_[1] ? &html_escape(ref($_[1]) ? $_[1]->{'value'} : $_[1]) : "";
}

# parse_opt(&config, name, [&checkfunc])
sub parse_opt
{
if (defined($in{"$_[1]_default"}) && $in{"$_[1]_default"} eq $in{$_[1]} ||
    !defined($in{"$_[1]_default"}) && $in{"$_[1]_def"}) {
	&save_directives($_[0], $_[1], [ ], 1);
	}
else {
	&{$_[2]}($in{$_[1]}) if ($_[2]);
	&save_directives($_[0], $_[1], [ $in{$_[1]} ], 1);
	}
}

# edit_textbox(name, &values, width, height)
sub edit_textbox
{
print "<textarea name=$_[0] cols=$_[2] rows=$_[3]>";
foreach $v (@{$_[1]}) {
	print "$v\n";
	}
print "</textarea>\n";
}

# parse_textbox(&config, name)
sub parse_textbox
{
$in{$_[1]} =~ s/^\s+//;
$in{$_[1]} =~ s/\s+$//;
local @v = split(/\s+/, $in{$_[1]});
&save_directives($_[0], $_[1], \@v, 1);
}

# get_procmailrc()
# Returns the full paths to the procmail config files in use, the last one
# being the user's config
sub get_procmailrc
{
if ($module_info{'usermin'}) {
	local @rv;
	push(@rv, $config{'global_procmailrc'});
	push(@rv, $config{'procmailrc'} || $procmail::procmailrc);
	return @rv;
	}
else {
	return ( $access{'procmailrc'} || $config{'procmailrc'} || $procmail::procmailrc );
	}
}

# find_default(name, compiled-in-default)
sub find_default
{
if ($config{'global_cf'}) {
	local $gconf = &get_config($config{'global_cf'});
	local $v = &find_value($_[0], $gconf);
	return $v if (defined($v));
	}
return $_[1];
}

# can_use_page(page)
# Returns 1 if some page can be used, 0 if not
sub can_use_page
{
local %avail_icons;
if ($module_info{'usermin'}) {
	%avail_icons = map { $_, 1 } split(/,/, $config{'avail_icons'});
	}
else {
	%avail_icons = map { $_, 1 } split(/,/, $access{'avail'});
	}
local $p = $_[0] eq "simple" ? "header" : $_[0];
return $avail_icons{$p};
}

# can_use_check(page)
# Calls error if some page cannot be used
sub can_use_check
{
&can_use_page($_[0]) || &error($text{'ecannot'});
}

# get_spamassassin_version(&out)
sub get_spamassassin_version
{
local $out;
&execute_command("$config{'spamassassin'} -V", undef, \$out, \$out, 0, 1);
${$_[0]} = $out if ($_[0]);
return $out =~ /(version|Version:)\s+(\S+)/ ? $2 : undef;
}

# version_atleast(num)
sub version_atleast
{
if (!$version_cache) {
	$version_cache = &get_spamassassin_version();
	}
return $version_cache >= $_[0];
}

# spam_file_folder()
sub spam_file_folder
{
&foreign_require("mailbox", "mailbox-lib.pl");
local ($sf) = grep { $_->{'spam'} } &mailbox::list_folders();
return $sf;
}

# disable_indexing(&folder)
sub disable_indexing
{
if (!$config{'index_spam'}) {
	$mailbox::config{'index_min'} = 1000000000;
	unlink(&mailbox::user_index_file($_[0]->{'file'}));
	}
}

# get_process_pids()
# Returns the PIDs and names of SpamAssassin daemon processes like spamd
sub get_process_pids
{
local ($pn, @pids);
foreach $pn (split(/\s+/, $config{'processes'})) {
	push(@pids, map { [ $_, $pn ] } &find_byname($pn));
	}
return @pids;
}

sub lock_spam_files
{
local $conf = &get_config();
@spam_files = &unique(map { $_->{'file'} } @$conf);
local $f;
foreach $f (@spam_files) {
	&lock_file($f);
	}
}

sub unlock_spam_files
{
local $f;
foreach $f (@spam_files) {
	&unlock_file($f);
	}
}

# show_buttons(number)
sub show_buttons
{
print "<table width=100%> <tr>\n";
local $onclick = "onClick='return check_clicks(form)'"
	if (defined(&check_clicks_function));
print "<td align=left><input type=submit name=inbox value=\"$text{'mail_inbox'}\" $onclick></td>\n";
print "<td align=left><input type=submit name=whitelist value=\"$text{'mail_whitelist2'}\" $onclick></td>\n";
if (&has_command($config{'sa_learn'})) {
	print "<td align=center><input type=submit name=ham value=\"$text{'mail_ham'}\" $onclick></td>\n";
	}
print "<td align=right><input type=submit name=delete value=\"$text{'mail_delete'}\" $onclick></td>\n";
print "<td align=right><input type=submit name=razor value=\"$text{'mail_razor'}\" $onclick></td>\n";
print "</tr></table>\n";
}

# restart_spamd()
# Re-start all SpamAssassin processes, or return an error message
sub restart_spamd
{
if ($config{'restart_cmd'}) {
	local $out = &backquote_logged(
		"$config{'restart_cmd'} 2>&1 </dev/null");
	if ($? || $out =~ /error|failed/i) {
		return "<pre>$out</pre>";
		}
	}
else {
	local @pids = &get_process_pids();
	@pids || return $text{'apply_none'};
	local $p;
	foreach $p (@pids) {
		&kill_logged("HUP", $p->[0]);
		}
	}
return undef;
}

# find_spam_recipe(&recipes)
# Returns the recipe that runs spamassassin
sub find_spam_recipe
{
local $r;
foreach $r (@{$_[0]}) {
	if ($r->{'action'} =~ /spamassassin/i ||
	    $r->{'action'} =~ /spamc/i) {
		return $r;
		}
	}
return undef;
}

# find_file_recipe(&recipes)
# Returns the recipe for delivering mail based on the X-Spam-Status header
sub find_file_recipe
{
local ($r, $c);
foreach $r (@{$_[0]}) {
	foreach $c (@{$r->{'conds'}}) {
		if ($c->[1] =~ /X-Spam-Status/i) {
			return $r;
			}
		}
	}
return undef;
}

# find_virtualmin_recipe(&recipes)
# Returns the recipe that runs the Virtualmin lookup command
sub find_virtualmin_recipe
{
local ($r, $c);
foreach $r (@{$_[0]}) {
	if ($r->{'action'} =~ /^VIRTUALMIN=/) {
		return $r;
		}
	}
return undef;
}

# find_force_default_receipe(&recipes)
# Returns the recipe that forces delivery to $DEFAULT, used by Virtualmin and
# others to prevent per-user .procmailrc settings
sub find_force_default_receipe
{
local ($r, $c);
foreach $r (@{$_[0]}) {
	if ($r->{'action'} eq '$DEFAULT' && !@{$r->{'conds'}}) {
		return $r;
		}
	}
return undef;
}

# get_simple_tests(&conf)
sub get_simple_tests
{
local ($conf) = @_;
local (@simple, %simple);
foreach my $h (&find("header", $conf)) {
	if ($h->{'value'} =~ /^(\S+)\s+(\S+)\s+=~\s+\/(.*)\/(\S*)\s*$/) {
		push(@simples, { 'header_dir' => $h,
				 'name' => $1,
				 'header' => lc($2),
			 	 'regexp' => $3,
				 'flags' => $4, });
		$simples{$1} = $simples[$#simples];
		}
	}
foreach my $b (&find("body", $conf), &find("full", $conf),
	       &find("uri", $conf)) {
	if ($b->{'value'} =~ /^(\S+)\s+\/(.*)\/(\S*)\s*$/) {
		push(@simples, { $b->{'name'}.'_dir' => $b,
				 'name' => $1,
				 'header' => $b->{'name'},
			 	 'regexp' => $2,
				 'flags' => $3, });
		$simples{$1} = $simples[$#simples];
		}
	}
foreach my $s (&find("score", $conf)) {
	if ($s->{'value'} =~ /^(\S+)\s+(\S+)/ && $simples{$1}) {
		$simples{$1}->{'score_dir'} = $s;
		$simples{$1}->{'score'} = $2;
		}
	}
foreach my $d (&find("describe", $conf)) {
	if ($d->{'value'} =~ /^(\S+)\s+(\S.*)/ && $simples{$1}) {
		$simples{$1}->{'describe_dir'} = $d;
		$simples{$1}->{'describe'} = $2;
		}
	}
return @simples;
}

# get_procmail_command()
# Returns the command that should be used in /etc/procmailrc to call
# spamassassin, such as spamc or the full spamassassin path
sub get_procmail_command
{
if ($config{'procmail_cmd'} eq '*') {
	# Is spamd running?
	if (&get_process_pids()) {
		local $spamc = &has_command("spamc");
		return $spamc if ($spamc);
		}
	return &has_command($config{'spamassassin'});
	}
elsif ($config{'procmail_cmd'}) {
	return $config{'procmail_cmd'};
	}
else {
	return &has_command($config{'spamassassin'});
	}
}

# execute_before(section)
# If a before-change command is configured, run it. If it fails, call error
sub execute_before
{
local ($section) = @_;
if ($config{'before_cmd'}) {
	$ENV{'SPAM_SECTION'} = $section;
	local $out;
	local $rv = &execute_command(
			$config{'before_cmd'}, undef, \$out, \$out);
	$rv && &error(&text('before_ecmd',
			    "<pre>".&html_escape($out)."</pre>"));
	}
}

# execute_after(section)
# If a after-change command is configured, run it. If it fails, call error
sub execute_after
{
local ($section) = @_;
if ($config{'after_cmd'}) {
	$ENV{'SPAM_SECTION'} = $section;
	local $out;
	local $rv = &execute_command(
			$config{'after_cmd'}, undef, \$out, \$out);
	$rv && &error(&text('after_ecmd',
			    "<pre>".&html_escape($out)."</pre>"));
	}
}

1;

