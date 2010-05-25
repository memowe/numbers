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

app->session->default_expiration( 60 * 60 * 24 * 365 * 42 );

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
<style type="text/css">

body {
    margin          : 0;
    padding         : 0;
    font-family     : Helvetica, Arial, sans-serif;
    font-size       : 15px;
}

#content {
    width           : 600px;
    margin          : 50px auto 20px;
    padding         : 50px;
    background-color: #dde;
    border-radius   : 50px;
    -moz-border-radius: 50px;
    -webkit-border-radius: 50px;
}

address {
    width           : 600px;
    margin          : 20px auto 50px;
    padding         : 0;
    font-size       : .8em;
    color           : gray;
    background-color: transparent;
}

a {
    color           : black;
}

h1 {
    color           : white;
    background-color: transparent;
    font-size       : 5em;
    margin          : -56px -50px 20px;
    padding         : 0 50px 10px;
    border-bottom   : 30px solid #d2d2e4;
}

pre {
    background-color: #f0f0f8;
    color           : #333;
    padding         : .8em 1em;
    margin          : 1em 0;
    border-radius   : .5em;
    -moz-border-radius: .5em;
    -webkit-border-radius: .5em;
}

pre code {
    font-size       : 12px;
    font-family     : monospace;
}

#comp {
    margin          : 0;
    padding         : .7em 2ex .5em;
    background-color: white;
    color           : black;
    font-size       : 1.5em;
    text-align      : center;
    border-radius   : .5em;
    -moz-border-radius: .5em;
    -webkit-border-radius: .5em;
}

#comp .boundary {
    color           : #ccc;
}

#comp strong {
    font-weight     : bold;
    font-size       : 1.5em;
    padding         : 0 1ex;
}

#number {
    font-size       : 15em;
    font-weight     : bold;
    background-color: white;
    color           : black;
    margin          : 0;
    padding         : .2em .5ex .1em;
    text-align      : center;
    border-radius   : .05em;
    -moz-border-radius: .05em;
    -webkit-border-radius: .05em;
}

form p {
    text-align      : center;
    font-size       : 2em;
}

input {
    font-size       : inherit;
    width           : 20%;
    text-align      : center;
    padding         : .1em;
    border          : 5px solid #aaa;
}

input:focus {
    border-color    : black;
}

input[type=submit] {
    color           : #333;
    text-shadow     : 1px 1px 0px white;
    background-color: #ddd;
    cursor          : pointer;
}

input[type=submit]:hover {
    border-color    : black;
}

input.critical {
    text-decoration : blink;
    background-color: yellow;
    color           : black;
    text-shadow     : none;
    border-color    : #880;
}

input.fail {
    text-decoration : blink;
    background-color: red;
    color           : black;
    text-shadow     : none;
    border-color    : maroon;
}

#stats {
    margin          : 1em -50px 0;
    padding         : .6em 50px .5em;
    color           : #666;
    background-color: #d2d2e4;
    text-shadow     : 1px 1px 1px #eee;
}

</style>
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
