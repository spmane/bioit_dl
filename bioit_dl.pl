#!/usr/bin/perl
use strict;
use warnings;
use Cwd;
use File::Basename;
use File::Path;
use WWW::Mechanize;
use HTTP::Cookies;
use HTML::TreeBuilder;
	

my $login    = shift or die "Usage: perl $0 <email> <pasword>\n";
my $password = shift or die "Usage: perl $0 <email> <pasword>\n";;

my $base="http://www.chiresource.com/BIT-06-12/"; 
my $url=$base . "login.asp";
my $userfield="UserName";
my $passfield="password";

my $agent = WWW::Mechanize->new( autocheck => 1);

# Set up cookie jar
$agent->cookie_jar(HTTP::Cookies->new);


print STDERR "Loading page to login ... ";
$agent->get($url);
die $agent->response->status_line unless $agent->success;
$agent->field($userfield => $login);
$agent->field($passfield => $password);
$agent->click();
print STDERR "done.\n";


my @pdf_links;
my @presentation_links; #html pages linking to PDFs
my %seen_links;
my %visited_links;

print STDERR "Fetching agenda and speaker links ... ";

$url= $base . "programs.asp";
$agent->get($url);
die $agent->response->status_line unless $agent->success;
if ($agent->success){
	$agent->save_content( "index.html" );
	parseContent($agent->content)
}
print STDERR "done.\n";


print STDERR "Fetching presentation links \n";

foreach my $link (@presentation_links){
	$url = $base . $link;
	my($filename, $dir, $suffix) = fileparse($link);
	$filename=~s/\.asp/.html/;
	print STDERR "\r$url                                                  ";
	next if exists $visited_links{$url};
	$agent->get($url);
	if ($agent->success){
		$agent->save_content( $filename );
		parseContent($agent->content)
	}
	$visited_links{$url}=1;
	print STDERR ".";
	sleep(1);
}
print STDERR " done.\n";

# Download PDFs and save them in their respective folders
my $currWorkDir = &Cwd::cwd();
foreach my $link (@pdf_links){
	my($filename, $dir, $suffix) = fileparse($link);
	mkpath($dir);
	chdir($dir);
	$url = $base . $link;
	$agent->get($url);
	if ($agent->success){
		$agent->save_content( $filename );
		print STDERR "$filename saved.\n";
	}else{
		print STDERR "$filename failed.\n";
	}
	chdir($currWorkDir);
	sleep(1);
}
print STDERR "Downloaded ", scalar(@pdf_links), " pdf files.\n";

# parse html and grab pdf and html page links
sub parseContent{
	my $content=shift;
	my $root = HTML::TreeBuilder->new();
	$root->parse($content);
	$root->eof();
	my @data= $root->look_down( sub {$_[0]->tag() eq 'a'  ,"href" => qr//  } );	
	foreach my $line(@data){
		my $link=$line->attr('href') or next;
		#print $link,"\n" if $link=~/pdf/;
		$link=~s/\%20/ /g;
		if($link=~/\.pdf/){
			push @pdf_links,$link if ! exists $seen_links{$link};
				$seen_links{$link}=1;
		}elsif($link=~/Presentations_.*asp$/ or $link=~/posters\.asp$/){
			push @presentation_links,$link;
		}
	}
}
