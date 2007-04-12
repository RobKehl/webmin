# quota-lib.pl
# Common functions for quota management.

do '../web-lib.pl';
&init_config();
do '../ui-lib.pl';
if ($gconfig{'os_type'} =~ /^\S+\-linux$/) {
	do "linux-lib.pl";
	}
else {
	do "$gconfig{'os_type'}-lib.pl";
	}
if ($module_info{'usermin'}) {
	&switch_to_remote_user();
	}
else {
	%access = &get_module_acl();
	&foreign_require("mount", "mount-lib.pl");
	}

$email_cmd = "$module_config_directory/email.pl";

# list_filesystems()
# Returns a list of details of local filesystems on which quotas are supported
#  directory device type options quotacan quotanow
sub list_filesystems
{
local $f;
local @mtab = &mount::list_mounted();
foreach $f (&mount::list_mounts()) {
	$fmap{$f->[0],$f->[1]} = $f;
	}
map { $_->[4] = &quota_can($_, $fmap{$_->[0],$_->[1]}) } @mtab;
map { $_->[5] = &quota_now($_, $fmap{$_->[0],$_->[1]}) } @mtab;
return grep { $_->[4] } @mtab;
}

# parse_options(type, options)
# Convert an options string for some filesystem into the associative
# array %options
sub parse_options
{
local($_);
undef(%options);
if ($_[0] ne "-") {
	foreach (split(/,/, $_[0])) {
		if (/^([^=]+)=(.*)$/) { $options{$1} = $2; }
		else { $options{$_} = ""; }
		}
	}
}

# user_quota(user, filesystem)
# Returns an array of  ublocks, sblocks, hblocks, ufiles, sfiles, hfiles
# for some user, or an empty array if no quota has been assigned
sub user_quota
{
local (%user, $n, $i);
$n = &filesystem_users($_[1]);
for($i=0; $i<$n; $i++) {
	if ($user{$i,'user'} eq $_[0]) {
		return ( $user{$i,'ublocks'}, $user{$i,'sblocks'},
			 $user{$i,'hblocks'}, $user{$i,'ufiles'},
			 $user{$i,'sfiles'},  $user{$i,'hfiles'} );
		}
	}
return ();
}

# group_quota(group, filesystem)
# Returns an array of  ublocks, sblocks, hblocks, ufiles, sfiles, hfiles
# for some group, or an empty array if no quota has been assigned
sub group_quota
{
local (%group, $n, $i);
$n = &filesystem_groups($_[1]);
for($i=0; $i<$n; $i++) {
	if ($group{$i,'group'} eq $_[0]) {
		return ( $group{$i,'ublocks'}, $group{$i,'sblocks'},
			 $group{$i,'hblocks'}, $group{$i,'ufiles'},
			 $group{$i,'sfiles'},  $group{$i,'hfiles'} );
		}
	}
return ();
}

# edit_user_quota(user, filesys, sblocks, hblocks, sfiles, hfiles)
# Sets the disk quota for some user
sub edit_user_quota
{
if ($config{'user_setquota_command'} &&
    &has_command((split(/\s+/, $config{'user_setquota_command'}))[0])) {
	# Use quota setting command
	local $cmd = $config{'user_setquota_command'}." ".quotemeta($_[0])." ".
		     $_[2]." ".$_[3]." ".$_[4]." ".$_[5]." ".quotemeta($_[1]);
	local $out = &backquote_logged("$cmd 2>&1 </dev/null");
	&error("<tt>".&html_escape($out)."</tt>") if ($?);
	}
else {
	# Call the quota editor
	$ENV{'EDITOR'} = $ENV{'VISUAL'} = "$module_root_directory/edquota.pl";
	$ENV{'QUOTA_USER'} = $_[0];
	$ENV{'QUOTA_FILESYS'} = $_[1];
	$ENV{'QUOTA_SBLOCKS'} = $_[2];
	$ENV{'QUOTA_HBLOCKS'} = $_[3];
	$ENV{'QUOTA_SFILES'} = $_[4];
	$ENV{'QUOTA_HFILES'} = $_[5];
	local $user = $_[0];
	if ($edquota_use_ids) {
		# Use UID instead of username
		if ($user =~ /^#(\d+)$/) {
			$user = $1;
			}
		else {
			local $uid = getpwnam($user);
			$user = $uid if (defined($uid));
			}
		}
	&system_logged("$config{'user_edquota_command'} ".
		       quotemeta($user)." >/dev/null 2>&1");
	}
}

# edit_group_quota(group, filesys, sblocks, hblocks, sfiles, hfiles)
# Sets the disk quota for some group
sub edit_group_quota
{
if ($config{'group_setquota_command'} &&
    &has_command((split(/\s+/, $config{'group_setquota_command'}))[0])) {
	# Use quota setting command
	local $cmd = $config{'group_setquota_command'}." ".quotemeta($_[0])." ".
		     $_[2]." ".$_[3]." ".$_[4]." ".$_[5]." ".quotemeta($_[1]);
	local $out = &backquote_logged("$cmd 2>&1 </dev/null");
	&error("<tt>".&html_escape($out)."</tt>") if ($?);
	}
else {
	# Call the editor
	$ENV{'EDITOR'} = $ENV{'VISUAL'} = "$module_root_directory/edquota.pl";
	$ENV{'QUOTA_USER'} = $_[0];
	$ENV{'QUOTA_FILESYS'} = $_[1];
	$ENV{'QUOTA_SBLOCKS'} = $_[2];
	$ENV{'QUOTA_HBLOCKS'} = $_[3];
	$ENV{'QUOTA_SFILES'} = $_[4];
	$ENV{'QUOTA_HFILES'} = $_[5];
	local $group = $_[0];
	if ($edquota_use_ids) {
		# Use GID instead of group name
		if ($group =~ /^#(\d+)$/) {
			$group = $1;
			}
		else {
			local $gid = getgrnam($group);
			$group = $gid if (defined($gid));
			}
		}
	&system_logged("$config{'group_edquota_command'} ".
		       quotemeta($group)." >/dev/null 2>&1");
	}
}

# edit_user_grace(filesystem, btime, bunits, ftime, funits)
# Change the grace times for blocks and files on some filesystem
sub edit_user_grace
{
$ENV{'EDITOR'} = $ENV{'VISUAL'} = "$module_root_directory/edgrace.pl";
$ENV{'QUOTA_FILESYS'} = $_[0];
$ENV{'QUOTA_BTIME'} = $_[1];
$ENV{'QUOTA_BUNITS'} = $_[2];
$ENV{'QUOTA_FTIME'} = $_[3];
$ENV{'QUOTA_FUNITS'} = $_[4];
&system_logged($config{'user_grace_command'});
}

# edit_group_grace(filesystem, btime, bunits, ftime, funits)
# Change the grace times for blocks and files on some filesystem
sub edit_group_grace
{
$ENV{'EDITOR'} = $ENV{'VISUAL'} = "$module_root_directory/edgrace.pl";
$ENV{'QUOTA_FILESYS'} = $_[0];
$ENV{'QUOTA_BTIME'} = $_[1];
$ENV{'QUOTA_BUNITS'} = $_[2];
$ENV{'QUOTA_FTIME'} = $_[3];
$ENV{'QUOTA_FUNITS'} = $_[4];
&system_logged($config{'group_grace_command'});
}

# quota_input(name, value, [blocksize])
# Prints an input for selecting a quota or unlimited, in a table
sub quota_input
{
print "<td nowrap>",&ui_radio($_[0]."_def", $_[1] == 0 ? 1 : 0,
			      [ [ 1, $text{'quota_unlimited'} ], [ 0, " " ] ]);
print &quota_inputbox(@_);
print "</td> </tr>\n";
}

# quota_inputbox(name, value, [blocksize])
# Returns an input for selecting a quota
sub quota_inputbox
{
if ($_[2]) {
	# We know the real size, so can offer units
	local $sz = $_[1]*$_[2];
	local $units = 1;
	if ($sz >= 10*1024*1024*1024) {
		$units = 1024*1024*1024;
		}
	elsif ($sz >= 10*1024*1024) {
		$units = 1024*1024;
		}
	elsif ($sz >= 10*1024) {
		$units = 1024;
		}
	else {
		$units = 1;
		}
	$sz = $sz == 0 ? "" : sprintf("%.2f", ($sz*1.0)/$units);
	return &ui_textbox($_[0], $sz, 8).
	       &ui_select($_[0]."_units", $units,
			 [ [ 1, "bytes" ], [ 1024, "kB" ], [ 1024*1024, "MB" ],
			   [ 1024*1024*1024, "GB" ] ]);
	}
else {
	# Just show blocks
	return &ui_textbox($_[0], $_[1], 8);
	}
}

# quota_parse(name, [bsize], [nodef])
sub quota_parse
{
if ($in{$_[0]."_def"} && !$_[2]) {
	return 0;
	}
elsif ($_[1]) {
	# Include units, and covert to blocks
	return int($in{$_[0]}*$in{$_[0]."_units"}/$_[1]);
	}
else {
	# Just use blocks
	return int($in{$_[0]});
	}
}

# can_edit_filesys(filesys)
sub can_edit_filesys
{
local $fs;
foreach $fs (split(/\s+/, $access{'filesys'})) {
	return 1 if ($fs eq "*" || $fs eq $_[0]);
	}
return 0;
}

# can_edit_user(user)
sub can_edit_user
{
if ($access{'umode'} == 0) {
	return 1;
	}
elsif ($access{'umode'} == 3) {
	local @u = getpwnam($_[0]);
	return $access{'users'} == $u[3];
	}
elsif ($access{'umode'} == 4) {
	local @u = getpwnam($_[0]);
	return (!$access{'umin'} || $u[2] >= $access{'umin'}) &&
	       (!$access{'umax'} || $u[2] <= $access{'umax'});
	}
else {
	local ($u, %ucan);
	map { $ucan{$_}++ } split(/\s+/, $access{'users'});
	return $access{'umode'} == 1 && $ucan{$_[0]} ||
	       $access{'umode'} == 2 && !$ucan{$_[0]};
	}
}

# can_edit_group(group)
sub can_edit_group
{
return 1 if ($access{'gmode'} == 0);
return 0 if ($access{'gmode'} == 3);
local ($g, %gcan);
map { $gcan{$_}++ } split(/\s+/, $access{'groups'});
return $access{'gmode'} == 1 && $gcan{$_[0]} ||
       $access{'gmode'} == 2 && !$gcan{$_[0]};
}

# filesystem_info(filesystem, &hash, count, [blocksize])
sub filesystem_info
{
local @fs = &free_space($_[0], $_[3]);
if ($_[3]) {
	local $i;
	foreach $i (0 .. 3) {
		$fs[$i] = $i < 2 ? &nice_size($fs[$i]*$_[3])
				 : int($fs[$i]);
		}
	}
if ($_[1]) {
	local $bt = 0;
	local $ft = 0;
	local $i;
	for($i=0; $i<$_[2]; $i++) {
		$bt += $_[1]->{$i,'hblocks'};
		$ft += $_[1]->{$i,'hfiles'};
		}
	if ($_[3]) {
		$bt = &nice_size($bt*$_[3]);
		}
	return ( "$fs[0] total / $fs[1] free / $bt granted",
		 "$fs[2] total / $fs[3] free / $ft granted" );
	}
else {
	return ( "$fs[0] total / $fs[1] free",
		 "$fs[2] total / $fs[3] free" );
	}
}

# block_size(dir, [for-filesys])
# Returns the size (in bytes) of blocks on some filesystem
sub block_size
{
return undef if (!$config{'block_mode'});
return undef if (!defined(&quota_block_size) &&
		 !defined(&fs_block_size));
local @mounts = &mount::list_mounted();
local ($mount) = grep { $_->[0] eq $_[0] } @mounts;
if ($mount) {
	if ($_[1]) {
		return &fs_block_size(@$mount);
		}
	else {
		if (defined(&quota_block_size)) {
			return &quota_block_size(@$mount);
			}
		else {
			return &fs_block_size(@$mount);
			}
		}
	}
return undef;
}

# print_limit(amount, no-blocks)
sub print_limit
{
if ($_[0] == 0) { print "<td>$text{'quota_unlimited'}</td>\n"; }
elsif ($bsize && !$_[1]) { print "<td>",&nice_size($_[0]*$bsize),"</td>"; }
else { print "<td>$_[0]</td>\n"; }
}

# nice_limit(amount, bsize, no-blocks)
sub nice_limit
{
local ($amount, $bsize, $noblocks) = @_;
return $amount == 0 ? $text{'quota_unlimited'} :
       $bsize && !$noblocks ? &nice_size($amount*$bsize) : $amount;
}

sub print_grace
{
print "<td>",($_[0] || "<br>"),"</td>\n";
}

sub find_email_job
{
&foreign_require("cron", "cron-lib.pl");
local @jobs = &cron::list_cron_jobs();
local ($job) = grep { $_->{'command'} eq $email_cmd } @jobs;
return $job;
}

# create_email_job()
# Creates the cron job for scheduled emailing
sub create_email_job
{
&foreign_require("cron", "cron-lib.pl");
local $job = &find_email_job();
if (!$job) {
	$job = { 'user' => 'root',
		 'command' => $email_cmd,
		 'active' => 1,
		 'mins' => '0,10,20,30,40,50',
		 'hours' => '*',
		 'days' => '*',
		 'months' => '*',
		 'weekdays' => '*' };
	&lock_file(&cron::cron_file($job));
	&cron::create_cron_job($job);
	&cron::create_wrapper($email_cmd, $module_name, "email.pl");
	&unlock_file(&cron::cron_file($job));
	}
}

# trunc_space(string)
# Removes spaces from the start and end of a string
sub trunc_space
{
local $rv = $_[0];
$rv =~ s/^\s+//;
$rv =~ s/\s+$//;
return $rv;
}

# to_percent(used, total)
sub to_percent
{
if ($_[1]) {
	return $_[0]*100/$_[1];
	}
else {
	return 0;
	}
}

1;

