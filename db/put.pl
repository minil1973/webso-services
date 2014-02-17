#!/usr/bin/perl
######################################################################
# db/put.json
# 
# add any object to webso
#
# inputs:
#   any key : values  (keys are defined in config file)
#
# Contributors:
#   - Arnaud Gaudinat : 11/07/2013
######################################################################

use strict;
use CGI;
use JSON;
use lib "..";
use LWP::UserAgent;
use Config::Simple;
use Digest::MD5 qw(md5 md5_hex md5_base64);


my $q       = CGI->new;
my $cgi     = $q->Vars;

#print $$cgi;

# prepare the JSON msg
my $json    = JSON->new->allow_nonref;

my %perl_response = (    
    );

# print json header
print $q->header('application/json');

# reading the conf file
my $cfg     = new Config::Simple('../webso.cfg');



my $db_type = $cfg->param('db_type');
my $db_user = $cfg->param('db_user');
my $db_url  = $cfg->param('db_url');


if (Config::Simple->error()) {
    $perl_response{'debug_msg'} = Config::Simple->error();
    push @{$perl_response{'error'}},'Config file error';
}
else {
    my $deb_mod = $cfg->param('debug');
    my $id = q{};


    # create id depending of type of object
    # if source type
    if ($$cgi{$db_type} eq $cfg->param('t_source')) {
        $id = 's_'.md5_hex($$cgi{$db_user}.$$cgi{$db_url}); #add s_ for source
        if ($$cgi{refresh_rate}) {
            $$cgi{refresh_rate} = (60 * 23); # default rate each 23h
        }

    }

    $$cgi{id} = $id;

    my $json_text   = $json->pretty->encode($cgi);

    # concatenate query and response
    %perl_response = (%perl_response,%$cgi);

    # init user_agent
    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    $ua->env_proxy;

    # accessing values:
    #my $db_source = $cfg->param('db_source').'update -H \'Content-type:application/json\' -d ';

    my $req = HTTP::Request->new(
        POST => $cfg->param('ws_db').'update'
    );
    $req->content_type('application/json');
    $req->content('['.$json_text.']');

    my $response = $ua->request($req);


    if ($response->is_success) {
        $perl_response{success} = $json->decode( $response->decoded_content);  # or whatever
     
    }
    else {
        $perl_response{'error'} = 'sources server or service: '.$response->code;
        if ($deb_mod) {
            $perl_response{'debug_msg'} = $response->message;
        }
    }
}

my $json_response   = $json->pretty->encode(\%perl_response);
print $json_response; 
 