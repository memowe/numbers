#!/usr/bin/env perl

use Mojolicious::Lite;
use File::Basename;

use constant MAX => 100;

sub unisort {
    my %uniq = map { $_ => 1 } @_;
    return sort { $a <=> $b } keys %uniq;
}

sub submit_class {
    my $attempts = shift;
    return  $attempts < log(MAX)/log(2) * 0.7   ?   'ok'
        :   $attempts < log(MAX)/log(2) * 1.3   ?   'critical'
        :                                           'fail';
}

app->secret('42');

app->session->default_expiration( 60 * 60 * 24 * 30 );

# start a game
get '/' => sub {
    my $self = shift;

    my $number = int rand MAX+1;

    $self->session(
        number      => $number,
        attempts    => [],
    );

    $self->stash(
        attempts_lo => [],
        attempts_hi => [],
        attempts    => 0,
        max         => MAX,
        class       => submit_class(0),
    );

    $self->render('attempt');

} => 'play';

# attempt to solve
post '/' => sub {
    my $self = shift;

    my $attempt     = int $self->param('attempt');
    my $number      = $self->session('number');
    my $attempts    = $self->session('attempts');
    push @$attempts, $attempt;

    # reload after win
    unless ( defined $number ) {
        $self->redirect_to('play');
        return;
    }

    # win
    if ( $attempt == $number ) {

        my $games   = $self->session('games');
        my $average = $self->session('average');

        $self->session(
            games       => $games + 1,
            average     => ($games*$average + @$attempts) / ($games + 1),
            number      => undef,
            attempts    => [],
        );

        $self->stash( number => $number );
        $self->render('win');
    }
    else {
        $self->stash(
            attempts_lo => [ unisort grep $_ < $number => @$attempts ],
            attempts_hi => [ unisort grep $_ > $number => @$attempts ],
            attempts    => scalar @$attempts,
            max         => MAX,
            class       => submit_class(scalar @$attempts),
        );
    }
} => 'attempt';

get '/source' => sub {
    open my $source, '<', $0 or die $!;
    shift->stash( source => join '' => <$source> );
} => 'source';

app->start;

__DATA__

@@ attempt.html.ep
% layout 'numbers';
<h1>Try to guess!</h1>
<p id="comp">
    <span class="boundary">0 &le;</span>
% if (@$attempts_lo) {
    <span class="attempts"><%= join ' ' => @$attempts_lo %></span> &lt;
% }
    <strong>?</strong>
% if (@$attempts_hi) {
    &lt; <span class="attempts"><%= join ' ' => @$attempts_hi %></span>
% }
    <span class="boundary">&le; <%= $max %></span>
</p>
<form action="<%= url_for 'play' %>" method="post"><p>
    <input type="text" name="attempt" id="attempt">
    <input type="submit" value="#<%= $attempts + 1 %>" class="<%= $class %>">
</p></form>

@@ win.html.ep
% layout 'numbers';
<h1>You win!</h1>
<p id="number"><%= $number %></p>
<p><strong><a href="<%== url_for 'play' %>">Play again!</a></strong></p>

@@ source.html.ep
% layout 'numbers';
<h1>The source.</h1>
<pre><code><%= $source %></code></pre>
<p>
    OK, that's enough
    <a href="http://www.perl.org/">Perl</a>
    and
    <a href="http://mojolicious.org/">Mojolicious::Lite</a>
    for me.
    <strong><a href="<%== url_for 'play' %>">Let's play!</a></strong>
</p>

@@ layouts/numbers.html.ep
<!doctype html><html>
<head>
<title>numbers</title>
<link rel="stylesheet" type="text/css" href="/style.css">
</head>
<body onload="document.getElementById('attempt').focus()">
<div id="content">
<%== content %>
<p id="stats">
    played: <%= $session->{games} || 0 %>,
    average: <%= sprintf "%.2f", $session->{average} || 0 %>
</p>
</div>
<address>
    &copy; Mirko "memowe" Westermeier
    &mdash; <%= link_to source => {%>View source<%}%>
</address>
</body>
</html>
