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
use Time::localtime;
use HTML::Restrict;

use FindBin qw($Bin);
use Tools;


my $q       = CGI->new;
my $cgi     = $q->Vars;

#print $$cgi;

# prepare the JSON msg
my $json    = JSON->new->allow_nonref;

my %perl_response = (    
    );

my $callback = q{};

# print json header
# print $q->header('application/json');

# reading the conf file
my $cfg     = new Config::Simple("$Bin/../webso.cfg");
&Tools::init("$Bin/..");

my $db_type                 = $cfg->param('db_type');
my $db_user                 = $cfg->param('db_user');
my $db_password             = $cfg->param('db_password');
my $db_role                 = $cfg->param('db_role');
#my $db_compteur_sessions    = $cfg->param('db_compteur_sessions');
my $db_jeton                = $cfg->param('db_jeton');
my $db_url                  = $cfg->param('db_url');
my $db_creation_date        = $cfg->param('db_creation_date');
my $db_updating_date        = $cfg->param('db_updating_date');
my $db_query                = $cfg->param('db_query');
my $db_folder               = $cfg->param('db_folder');
my $db_domain               = $cfg->param('db_domain');
my $db_title                = $cfg->param('db_title');
my $db_widget_type          = $cfg->param('db_widget_type');
my $db_enable               = $cfg->param('db_enable');
my $db_weight               = $cfg->param('db_weight');


# current date
my $tm = localtime;
my $str_now = sprintf("%04d-%02d-%02d".'T'. "%02d:%02d:%02d".'Z', $tm->year+1900,($tm->mon)+1, $tm->mday, $tm->hour, $tm->min, $tm->sec);

if (Config::Simple->error()) {
    $perl_response{'debug_msg'} = Config::Simple->error();
    push @{$perl_response{'error'}},'Config file error';
}
else {
    my $deb_mod = $cfg->param('debug');
    my $id = q{};


    # create id depending of type of object
    # if source type
    my $rss_json_doc;
    if ($$cgi{$db_type} eq $cfg->param('t_source')) {
        $id = 's_'.md5_hex($$cgi{$db_user}.$$cgi{$db_url}); #add s_ for source
        if ($$cgi{refresh_rate_s}) {
            $$cgi{refresh_rate_s} = '12h'; # default rate each 23h
        }
        # if rss , not sure
        if ($$cgi{$db_title}) {
            my $hs = HTML::Restrict->new();
            $$cgi{$db_title} = $hs->process($$cgi{$db_title});
        }
        my %source;
        $source{$db_url}    = $$cgi{$db_url};
        $source{$db_user}   = $$cgi{$db_user};
        $source{'waiting_b'}= $$cgi{waiting_b};
        $source{id}         = $id;
        my $crawl_link  = 'false';
        my $indexing    = 'true';
        $rss_json_doc = Tools::fetchDocSource(\%source,$crawl_link,$indexing);
        #$perl_response{'error'} =  $error_msg;


    }
    if ($$cgi{$db_type} eq $cfg->param('t_validation')) {
        $id = 'v_'.md5_hex($$cgi{$db_user}.$$cgi{$db_url}); #add v_ for validation
    }
    if ($$cgi{$db_type} eq $cfg->param('t_user')) {
        $id = 'u_'.md5_hex($$cgi{$db_user}.$$cgi{$db_password}); #add e_ for user
        $$cgi{$db_password} = md5_hex($$cgi{$db_password});
        $$cgi{$db_role}     = $$cgi{$db_role};
    }
    if ($$cgi{$db_type} eq $cfg->param('t_document')) {
        $id = 'd_'.md5_hex($$cgi{$db_user}.$$cgi{$db_url}); #
    }
    if ($$cgi{$db_type} eq $cfg->param('t_report')) {
        $id = 'r_'.md5_hex($$cgi{$db_user}.$$cgi{$db_url});
    }
    #if ($$cgi{$db_type} eq $cfg->param('t_user')) {
    #    $id = 'u_'.md5_hex($$cgi{$db_user}.$$cgi{$db_url});
    #}
    if ($$cgi{$db_type} eq $cfg->param('t_folder')) {
        $id = 'f_'.md5_hex($$cgi{$db_user}.$$cgi{$db_url});
    }

    # id of watch depends of user, url, query
    if ($$cgi{$db_type} eq $cfg->param('t_watch')) {
        $id = 'w_'.md5_hex($$cgi{$db_user}.$$cgi{$db_url}.$$cgi{$db_query});
    }
    if ($$cgi{$db_type} eq $cfg->param('t_widget')) {
		$id = 'wg_'.md5_hex($$cgi{$db_user}.$$cgi{$db_widget_type}.$str_now);
    }

    if ($$cgi{$db_type} eq $cfg->param('t_tree')) {
            $id = 't_'.md5_hex($$cgi{$db_user}.$$cgi{$db_title});
    }

    if ($q->param('callback')) {
        $callback    = $q->param('callback');
    }

    ## delete callback
    delete $$cgi{'callback'};

    # add id

    $$cgi{id} = $id;

    # add current date

    $$cgi{$db_creation_date} = $str_now;
    $$cgi{$db_updating_date} = $str_now;

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
        $perl_response{success} = $json->decode( $response->content);  # or whatever
        $perl_response{nb_doc_added}=$$rss_json_doc{nb};
     
    }
    else {
        $perl_response{'error'} = 'sources server or service: '.$response->code;
        if ($deb_mod) {
            $perl_response{'debug_msg'} = $response->message;
        }
    }
}

my $json_response   = $json->pretty->encode(\%perl_response);

if ($callback) { 
    print 'Access-Control-Allow-Origin: *';
    print 'Access-Control-Allow-Methods: GET'; 
    print "Content-type: application/javascript; charset=utf-8\n\n";
    $json_response   = $callback.'('.$json_response.');';
} else { 
    # Header for access via browser, curl, etc. 
    print "Content-type: application/json\n\n"; 
} 

print $json_response; 
 
