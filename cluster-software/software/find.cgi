#!/usr/local/bin/perl
# Show a form in a popup window for selecting a package from the update system

require './software-lib.pl';
&ReadParse();

&popup_header($text{'find_title'});
print <<EOF;
<script>
function sel(m)
{
window.opener.ifield.value = m;
window.close();
return false;
}
</script>
EOF

# Show form for searching
print &ui_form_start("find.cgi");
print &ui_submit($text{'find_search'}),"\n";
print &ui_textbox("search", $in{'search'}, 20),"\n";
print &ui_form_end();

# Show results, if any
$search = $in{'search'};
if ($search) {
	if (defined(&update_system_search)) {
		# Call the search function
		@avail = &update_system_search($search);
		}
	else {
		# Scan through list manually
		@avail = &update_system_available();
		@avail = grep { $_->{'name'} =~ /\Q$search\E/i ||
				$_->{'desc'} =~ /\Q$search\E/i } @avail;
		}

	if (@avail) {
		$hasdesc = $avail[0]->{'desc'};
		print &ui_columns_start(
			[ $text{'find_name'},
			  $text{'find_version'},
			  $hasdesc ? ($text{'find_desc'}) : ( ) ], "100%");
		foreach $a (@avail) {
			$sel = $a->{'select'} || $a->{'name'};
			print &ui_columns_row(
				[ "<a href='' onClick='sel(\"$sel\")'>$a->{'name'}</a>",
				  $a->{'version'},
				  $hasdesc ? ($a->{'desc'}) : ( ) ]);
			}
		print &ui_columns_end();
		}
	else {
		print "<b>$text{'find_none'}</b><p>\n";
		}
	}

&popup_footer();

