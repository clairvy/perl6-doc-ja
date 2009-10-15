#!/usr/bin/perl

# Pod to XHTML converter by Toshiyuki Yamato
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.

use strict;
use warnings;

use File::Find;
use File::Spec;
use File::Path qw(make_path remove_tree);
use File::Temp;

use Pod::Xhtml;

my @found;
my @pod_names;
my @dir_names;

my $parser = Pod::Xhtml->new(
    FragmentOnly => 1,
    StringMode   => 1,
    MakeIndex    => 0,
    MakeMeta     => 0,
    TopLinks     => '',
);

print "chdir docs\n";
chdir 'docs' or die $!;
find( sub { push @found, $File::Find::name; }, '.');

foreach my $name (@found) {

    if (-d $name) {
        next if $name eq '.';
        push @dir_names, $name;
    }
    else {
        next unless $name =~ /\.pod$/i;
        push @pod_names, $name;
    }

}

chdir '..' or die $!;

foreach my $dir (@dir_names) {

    next if $dir =~ /Apocalypse|Exegesis|Magazine|man_pages/i;

    my $path = File::Spec->catdir('source', $dir);
    remove_tree( $path, {verbose => 1} );
    make_path( $path, {verbose => 1} );
}

foreach my $pod (@pod_names) {

    next if $pod =~ /Apocalypse|Exegesis|Magazine|man_pages/i;

    if ($pod =~ /S26-documentation/) {
        print "Skip: S26-documentation.pod contains Perl 6 Pod.\n";
        next;
    }

    my $pod_path = File::Spec->catfile('docs', $pod);
    open my $in_fh, $pod_path or die $!;
    my $pod_text = do { local $/; <$in_fh> };
    close $in_fh;

    $pod_text =~ s/=encoding.*$//m;
    $pod_text =~ s/=for\s+vim.*$//m;

    # remove utf8 unbreak space
    $pod_text =~ s/\xc2\xa0/ /g; 

    my $pod_title = undef;

    if ($pod =~ /table_index/) {
        $pod_title = 'Perl 6 table index';
    }
    elsif ($pod_text =~ /=head1\s+(?:TITLE|NAME)\s+([^\n]+)/) {
        $pod_title = $1;
    }
    elsif ($pod_text =~ /=TITLE\s+([^\n]+)/) {
        $pod_title = $1;
    }
    elsif ($pod_text =~ /=for\s+NAME\s+([^\n]+)/) {
        $pod_title = $1;
    }
    elsif ($pod_text =~ /=head1\s+([^\n]+)/) {
        $pod_title = $1;
    }

    my $temp_fh = File::Temp->new(UNLINK => 1, SUFFIX => '.pod');
    print {$temp_fh} $pod_text;
    $temp_fh->seek(0, 0);

    print "$pod_path -> ";
    my $output_path = File::Spec->catfile('source', $pod);
    $output_path =~ s/\.pod/\.html/i;
    print "$output_path\n";

    open my $out_fh, '>', $output_path or die $!;

    $parser->parse_from_filehandle($temp_fh, $out_fh);
    my $output = $parser->asString();

    # fix-up tags
    for ($output) {
        s|<br /><br /><pre>|</p>\n<pre>|g;
        s|<br /><br />|</p>\n<p>|g;
        s|</pre>\s*</p>|</pre>|g;
        s|<p>\s+</p>||g;
        s|</pre>\s*<pre>||g;
        s|\n</p>|</p>|g;
        s|\n</pre>|</pre>|g;
        s|<li>|<li><p>|g;
        s|</li>|</p></li>|g;
        s|\s+</div>|\n</div>|g;
        s|<pre>\ {4}|<pre>|g;
        s|^\ {4}||mg;
    }

    my $header = <<"HEADER";
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html lang="ja">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<meta http-equiv="Content-Style-Type" content="text/css">
<title>$pod_title</title>
</head>
HEADER

    my $footer = <<"FOOTER";

</body>
</html>
FOOTER

    $output = $header . $output . $footer;

#    use HTML::TreeBuilder;
#    my $tree = HTML::TreeBuilder->new;
#    $tree->p_strict(1);
#    $tree->parse($output);
#    $output = $tree->as_HTML(qq{<>&'"}, " " x 2, {});
#
#    use Encode;
#    Encode::_utf8_off($output);

#    use HTML::Tidy::libXML;
#    my $tidy = HTML::Tidy::libXML->new();
#    $output = $tidy->clean($output, 'utf8', 1);

#    use XML::Liberal;
#    my $lib = XML::Liberal->new('LibXML');
#    my $doc = $lib->parse_string($output);
#    $output = $doc->toString();

#    use XML::Twig;
#    my $twig= new XML::Twig;
#    $twig->set_indent(" " x 2);
#    $twig->parse($output);
#    $twig->set_pretty_print("indented");
#    $output = $twig->sprint();

    print {$out_fh} $output;
    close $out_fh;
}
