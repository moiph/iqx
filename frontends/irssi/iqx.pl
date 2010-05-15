use strict;
use JSON;
use Irssi;
use Fcntl;
use Data::Dumper;
use IO::Socket::INET;

use vars qw($VERSION %IRSSI);

$VERSION = '1.0';
%IRSSI = (
  authors     => 'Matt Sparks',
  contact     => 'ms@quadpoint.org',
  name        => 'iqx',
  description => 'Frontend for an IQ X server',
  license     => 'BSD',
  url         => 'http://quadpoint.org',
  changed     => '2010-05-15',
);

my $sock = 0;
my @event_queue;


##
# check callback server socket for data
sub check_socket
{
  return if !$sock;

  my $msg;
  $sock->recv($msg, 4096);
  if ($msg) {
    print "Got from server: $msg";

    my $server = Irssi::active_server();
    my $json = new JSON;
    my $stuff = $json->decode($msg);
    if ($stuff) {
      $server->command("msg #IQ $msg");
    } else {
      print "Failed to decode JSON: $msg";
    }
  }
}


sub open_socket
{
  my $server_hostname = Irssi::settings_get_str('iqx_server_hostname');
  my $server_port = Irssi::settings_get_int('iqx_server_port');

  if (!$server_hostname || !$server_port) {
    print "[iqx] set 'iqx_server_hostname' and 'iqx_server_port variables with /set";
    die;
  }

  $sock = IO::Socket::INET->new(PeerHost => $server_hostname,
                                PeerPort => $server_port,
                                Type => SOCK_STREAM);
  if (!$sock) {
    print "[iqx] Unable to connect to $server_hostname:$server_port: $!";
    return;
  }

  # set socket nonblocking
  my $flags = fcntl($sock, F_GETFL, 0);
  fcntl($sock, F_SETFL, $flags | O_NONBLOCK);

  Irssi::timeout_add(20, \&check_socket, []);
}


sub send_data_to_server
{
  my ($data) = @_;
  return 0 if !$sock;

  my $bytes = $sock->send($data);
  return ($bytes == length $data);
}


sub check_event_queue
{
  return if !scalar @event_queue;

  # try to send an item in the queue
  my $data = $event_queue[0];
  if (send_data_to_server($data)) {
    shift @event_queue;

    print "sent to server: $data";
  }
}


##
# send event to IQ X server
sub send_event
{
  my ($type, $data) = @_;
  my $json = new JSON;

  my $event = {'protocol' => 'irc',
               'eventName' => $type,
               'time' => time,
               'data' => $data};

  # put event in event queue
  my $event_data = $json->encode($event) . chr(0);

  my $max_queue_size = Irssi::settings_get_int('iqx_max_queue_size');
  if (length @event_queue >= $max_queue_size) {
    shift @event_queue;  # remove oldest queued event
  }
  push @event_queue, $event_data;

  # force checking the queue now, to minimize latency
  check_event_queue();
}


sub serialize_server
{
  my ($server) = @_;
  return 1;
}


#####################################################################
#
#  Event handlers
#
#####################################################################

sub event_pubmsg
{
  my ($server, $msg, $nick, $address, $target) = @_;

  my $data = {server => serialize_server($server),
              message => $msg,
              nickname => $nick,
              address => $address,
              target => $target};

  send_event('pubmsg', $data);
}


sub event_privmsg
{
  my ($server, $msg, $nick, $address, $target) = @_;

  my $data = {server => serialize_server($server),
              message => $msg,
              nickname => $nick,
              address => $address};

  send_event('privmsg', $data);
}


sub event_action
{
  my ($server, $msg, $nick, $address, $target) = @_;

  my $data = {server => serialize_server($server),
              message => $msg,
              nickname => $nick,
              address => $address,
              target => $target};

  send_event('action', $data);
}


sub event_notice
{
  my ($server, $msg, $nick, $address, $target) = @_;

  my $data = {server => serialize_server($server),
              message => $msg,
              nickname => $nick,
              address => $address,
              target => $target};

  send_event('notice', $data);
}


sub event_ctcp
{
  my ($server, $args, $nick, $address, $target) = @_;
  # ACTION events will be taken care of by event_action
  return if $args =~ /^ACTION /;

  my $data = {server => serialize_server($server),
              args => $args,
              address => $address,
              target => $target};

  send_event('ctcp', $data);
}


sub event_join
{
  my ($server, $channel, $nick, $address) = @_;

  my $data = {server => serialize_server($server),
              channel => $channel,
              nickname => $nick,
              address => $address};

  send_event('join', $data);
}


sub event_part
{
  my ($server, $channel, $nick, $address, $reason) = @_;

  my $data = {server => serialize_server($server),
              channel => $channel,
              nickname => $nick,
              address => $address};

  send_event('part', $data);
}


sub event_quit
{
  my ($server, $nick, $address, $reason) = @_;

  my $data = {server => serialize_server($server),
              nickname => $nick,
              address => $address,
              reason => $reason};

  send_event('quit', $data);
}


sub event_kick
{
  my ($server, $channel, $nick, $kicker, $address, $reason) = @_;

  my $data = {server => serialize_server($server),
              channel => $channel,
              nickname => $nick,
              kicker => $kicker,
              address => $address,
              reason => $reason};

  send_event('kick', $data);
}


sub event_nick
{
  my ($server, $newnick, $oldnick, $address) = @_;

  my $data = {server => serialize_server($server),
              new_nickname => $newnick,
              old_nickname => $oldnick,
              address => $address};

  send_event('nick', $data);
}


sub event_topic
{
  my ($server, $channel, $topic, $nick, $address) = @_;

  my $data = {server => serialize_server($server),
              channel => $channel,
              topic => $topic,
              nickname => $nick,
              address => $address};

  send_event('topic', $data);
}


sub event_mode
{
  my ($server, $msg, $nick, $address, $target) = @_;

  my $data = {server => serialize_server($server),
              message => $msg,
              nickname => $nick,
              address => $address,
              target => $target};

  send_event('mode', $data);
}


Irssi::signal_add('message public', 'event_pubmsg');
Irssi::signal_add('message private', 'event_privmsg');
Irssi::signal_add('message irc action', 'event_action');
Irssi::signal_add('message irc notice', 'event_notice');
Irssi::signal_add('ctcp msg', 'event_ctcp');
Irssi::signal_add('message join', 'event_join');
Irssi::signal_add('message part', 'event_part');
Irssi::signal_add('message quit', 'event_quit');
Irssi::signal_add('message kick', 'event_kick');
Irssi::signal_add('message nick', 'event_nick');
Irssi::signal_add('message topic', 'event_topic');
Irssi::signal_add('message irc mode', 'event_mode');

Irssi::settings_add_str('iqx', 'iqx_server_hostname', 'localhost');
Irssi::settings_add_int('iqx', 'iqx_server_port', 9889);
Irssi::settings_add_int('iqx', 'iqx_max_queue_size', 500);

Irssi::timeout_add(100, \&check_event_queue, []);

open_socket();