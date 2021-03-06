use strict;


use LWP::UserAgent;
use HTML::LinkExtor;
use URI::URL;


my $url = 'http://www.tdg.ch/services/divers/RSS/story/17730559';
my $url = 'http://www.bit-tech.net/rss/';


my $ua = LWP::UserAgent->new;

# Set up a callback that collect image links
my @imgs = ();
sub callback {
   my($tag, %attr) = @_;
   return if $tag eq 'img';  # we only look closer at <img ...>
   push(@imgs, values %attr);
}

# Make the parser.  Unfortunately, we don't know the base yet
# (it might be different from $url)
my $p = HTML::LinkExtor->new(\&callback);

# Request document and parse it as it arrives
my $res = $ua->request(HTTP::Request->new(GET => $url),
                    sub {$p->parse($_[0])});

# Expand all image URLs to absolute ones
my $base = $res->base;
@imgs = map { $_ = url($_, $base)->abs; } @imgs;

# Print them out
print join("\n", @imgs), "\n";