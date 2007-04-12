#!/usr/bin/perl

do './web-lib.pl';
&ReadParse();
&init_config();
%text = &load_language($current_theme);

if ($in{'mod'}) {
	$minfo = { &get_module_info($in{'mod'}) };
	}
else {
	$minfo = &get_goto_module();
	}
$goto = $minfo ? "$minfo->{'dir'}/" :
	$in{'page'} ? "" :
	       	      "right.cgi?open=system&open=status";
if ($minfo) {
	$cat = "?$minfo->{'category'}=1";
	}
if ($in{'page'}) {
	$goto .= "/".$in{'page'};
	}

if ($gconfig{'os_version'} eq "*") {
	$ostr = $gconfig{'real_os_type'};
	}
else {
	$ostr = "$gconfig{'real_os_type'} $gconfig{'real_os_version'}";
	}
$host = &get_display_hostname();
$title = $gconfig{'nohostname'} ? $text{'main_title2'} :
	&text('main_title', &get_webmin_version(), $host, $ostr);
if ($gconfig{'showlogin'}) {
	$title = $remote_user." : ".$title;
	}

# Show frameset
&PrintHeader();
$cols = &get_product_name() eq 'usermin' ? 180 : 230;
print <<EOF;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">

<html>
<head> <title>$title</title> </head>

<frameset cols="$cols,*" border=0>
	<frame name="left" src="left.cgi$cat" scrolling="auto">
	<frame name="right" src="$goto" noresize>
<noframes>
<body>

<p>This page uses frames, but your browser doesn't support them.</p>

</body>
</noframes>
</frameset>
</html>
EOF

