#!/usr/local/bin/perl
# nfs_server.cgi
# Called in a pop-up javascript window to display a list of known NFS
# servers, generated by broadcasting on the NFS port

require './mount-lib.pl';
use Socket;
&popup_header($text{'nfs_server'});
print <<EOF;
<script>
function choose(f)
{
top.opener.ifield.value = f;
window.close();
}
</script>
EOF

# send NFS null procedure call to broadcast address, and wait for
# 2 seconds for all replies
$msg = pack("NNNNNNNNNN",
	time(),	# xid
	0,	# CALL
	2,	# RPC version 2
	100003,	# nfs program
	2,	# nfs version
	0,	# null procedure
	0, 0,	# no authority
	0, 0,	# no credentials
	);
socket(SOCK, PF_INET, SOCK_DGRAM, getprotobyname("udp"));
setsockopt(SOCK, SOL_SOCKET, SO_BROADCAST, pack("l", 1));
send(SOCK, $msg, 0, pack_sockaddr_in(2049, inet_aton(&broadcast_addr())));
$tmstart = time();
while(time()-$tmstart < 2) {
	$rin = '';
	vec($rin, fileno(SOCK), 1) = 1;
	if (select($rout = $rin, undef, undef, 1)) {
		$from = recv(SOCK, $buf, 1024, 0);
		($fromport, $fromaddr) = unpack_sockaddr_in($from);
		$fromip = inet_ntoa($fromaddr);
		if ($fromip !~ /\.(255|0)$/ && !$already{$fromip}++) {
			push(@fromip, $fromip);
			push(@fromaddr, $fromaddr);
			}
		}
	}

if (@fromip) {
	print "<b>$text{'nfs_select'}</b><br>\n";
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'nfs_ip'}</b></td> ",
	      "<td><b>$text{'nfs_host'}</b></td> </tr>\n";
	for($i=0; $i<@fromip; $i++) {
		$fromhost = gethostbyaddr($fromaddr[$i], AF_INET);
		printf "<tr $cb> <td><a href=\"\" onClick='choose(\"%s\"); ".
		       "return false'>$fromip[$i]</a></td>\n",
			$fromhost ? $fromhost : $fromip[$i];
		printf "<td>%s</td> </tr>\n",
			$fromhost ? $fromhost : "<br>";
		}
	print "</table>\n";
	}
else {
	print "<b>$text{'nfs_none'}</b>.<p>\n";
	}

&popup_footer();


