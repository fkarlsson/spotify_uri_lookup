# 
# Spotify Irssi plugin 
# Decode and print information from Spotify URIs 
# 
# TODO: print private messages to right place (help me?) 
# 
# Modified by Fredrik Karlsson

# 
# Changes 
# 0.29: Fixed regexp 
# 0.30: Uses Spotify's metadata API instead
# 0.31: Outputs private message link infos to (msgs) window if it exists, otherwise prints it in current window
# 0.32: Added regex for play.spotify.com links
# 0.33: Track links with more than one artist only showed one of them because of stupid Perl comparison operators - fixed

use strict; 
use Irssi; 
use JSON;
use feature qw(switch say);

use Irssi::Irc; 
use LWP::UserAgent; 
use vars qw($VERSION %IRSSI);

$VERSION = '0.33'; 
%IRSSI = ( 
    authors     => 'Toni Viemerö, Fredrik Karlsson', 
    contact     => 'toni.viemero@iki.fi, fkarlsson@gmail.com', 

    name        => 'spotifyuri', 
    description => 'Decode Spotify URIs', 
    license     => 'BSD', 
    url         => 'http://spotify.url.fi/', 
); 

sub spotifyuri_public { 
    my ($server, $data, $nick, $mask, $target) = @_; 
    my $retval = spotifyuri_get($data); 
    my $win = $server->window_item_find($target); 
    Irssi::signal_continue(@_);

    if ($win) { 
        $win->print("%_Spotify:%_ $retval", MSGLEVEL_CRAP) if $retval; 
    } else { 
        Irssi::print("%_Spotify:%_ $retval") if $retval; 
    } 
} 
sub spotifyuri_private { 
    my ($server, $data, $nick, $mask) = @_; 
    my $retval = spotifyuri_get($data); 
    my $win = Irssi::window_find_name('(msgs)'); 
    Irssi::signal_continue(@_);

    if ($win) { 
        $win->print("%_Spotify:%_ $retval", MSGLEVEL_CRAP) if $retval; 
    } else { 
        Irssi::print("%_Spotify:%_ $retval") if $retval; 
    } 
} 
sub spotifyuri_parse { 
    my ($url) = @_; 
    if ($url =~ /(https*:\/\/(?:play|open).spotify.com\/|spotify:)(album|artist|track)([:\/])([a-zA-Z0-9]+)\/?/) { 
        return "http://ws.spotify.com/lookup/1/.json?uri=spotify:$2:$4";
    } 
    return 0; 
} 
sub spotifyuri_get { 
    my ($data) = @_; 

    my $url = spotifyuri_parse($data); 

    my $ua = LWP::UserAgent->new(env_proxy=>1, keep_alive=>1, timeout=>5); 
    $ua->agent("irssi/$VERSION " . $ua->agent()); 

    my $req = HTTP::Request->new('GET', $url); 
    my $res = $ua->request($req);

    if ($res->is_success()) { 
        my $json = JSON->new->utf8;
        my $json_data = $json->decode($res->content());
        my $result_string = '';

        my $type = $json_data->{info}->{type};
        given ($type) {
            when ('track') {
                my $artists = '';
                foreach my $artist(@{$json_data->{track}->{artists}}) {
                    if ($artists eq '') {
                        $artists = $artist->{name};
                    } else {
                        $artists .= ", " . $artist->{name};
                    }
                }

                $result_string = "$artists - $json_data->{track}->{name} %K[%n$json_data->{track}->{album}->{name}%K]%n";
            }
            when ('album') {
                my $album = $json_data->{album}->{name};
                my $album_year = $json_data->{album}->{released};
                my $artist = $json_data->{album}->{artist};

                $result_string = "$artist - $album %K[%n$album_year%K]%n";
            }
            when ('artist') {
                $result_string = $json_data->{artist}->{name};
            }
            default {
                $result_string = 'Error';
            }
        }

        return $result_string; 
    } 
    return 0; 
} 

Irssi::signal_add_last('message public', 'spotifyuri_public'); 
Irssi::signal_add_last('message private', 'spotifyuri_private'); 