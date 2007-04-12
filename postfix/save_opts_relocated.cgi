#!/usr/local/bin/perl
#
# postfix-module by Guillaume Cottenceau <gc@mandrakesoft.com>,
# for webmin by Jamie Cameron
#
# Copyright (c) 2000 by Mandrakesoft
#
# Permission to use, copy, modify, and distribute this software and its
# documentation under the terms of the GNU General Public License is hereby 
# granted. No representations are made about the suitability of this software 
# for any purpose. It is provided "as is" without express or implied warranty.
# See the GNU General Public License for more details.
#
#
# Save Postfix options ; special because for relocated tables


require './postfix-lib.pl';

&ReadParse();


$access{'relocated'} || &error($text{'relocated_ecannot'});
#      &ui_print_header(undef, $text{'opts_title'}, "");


&error_setup($text{'opts_err'});


&lock_postfix_files();
&before_save();
&save_options(\%in);
&ensure_map("relocated_maps");
&after_save();
&unlock_postfix_files();


&regenerate_relocated_table();

&reload_postfix();

&webmin_log("relocated");
&redirect("");



