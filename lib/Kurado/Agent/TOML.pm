package Kurado::Agent::TOML;

use 5.008005;
use strict;
use warnings;
use utf8;

use boolean qw//;
use TOML::Parser::Tokenizer qw/:constant/;
use TOML::Parser::Util qw/unescape_str/;

sub new {
    my $class = shift;
    my $args  = (@_ == 1 and ref $_[0] eq 'HASH') ? +shift : +{ @_ };
    return bless +{
        inflate_datetime => sub { $_[0] },
        inflate_boolean  => sub { $_[0] eq 'true' ? boolean::true : boolean::false },
        strict_mode      => 0,
        %$args,
    } => $class;
}

sub parse_file {
    my ($self, $file) = @_;
    open my $fh, '<:encoding(utf-8)', $file or die $!;
    return $self->parse_fh($fh);
}

sub parse_fh {
    my ($self, $fh) = @_;
    my $src = do { local $/; <$fh> };
    return $self->parse($src);
}

sub _tokenizer_class {
    my $self = shift;
    return 'TOML::Parser::Tokenizer';
}

our @TOKENS;
our $ROOT;
our $CONTEXT;
sub parse {
    my ($self, $src) = @_;

    local $ROOT    = {};
    local $CONTEXT = $ROOT;
    local @TOKENS  = $self->_tokenizer_class->tokenize($src);
    return $self->_parse_tokens();
}

sub _parse_tokens {
    my $self = shift;

    while (my $token = shift @TOKENS) {
        my ($type, $val) = @$token;
        if ($type eq TOKEN_TABLE) {
            $self->_parse_table($val);
        }
        elsif ($type eq TOKEN_ARRAY_OF_TABLE) {
            $self->_parse_array_of_table($val);
        }
        elsif ($type eq TOKEN_KEY) {
            my $token = shift @TOKENS;
            die "Duplicate key. key:$val" if exists $CONTEXT->{$val};
            $CONTEXT->{$val} = $self->_parse_value_token($token);
        }
        elsif ($type eq TOKEN_COMMENT) {
            # pass through
        }
        else {
            die "Unknown case. type:$type";
        }
    }

    return $CONTEXT;
}

sub _parse_table {
    my ($self, $key) = @_;

    local $CONTEXT = $ROOT;
    for my $k (split /\./, $key) {
        if (exists $CONTEXT->{$k}) {
            $CONTEXT = ref $CONTEXT->{$k} eq 'ARRAY' ? $CONTEXT->{$k}->[-1] :
                       ref $CONTEXT->{$k} eq 'HASH'  ? $CONTEXT->{$k}       :
                       die "invalid structure. $key cannot be `Table`";
        }
        else {
            $CONTEXT = $CONTEXT->{$k} ||= +{};
        }
    }

    $self->_parse_tokens();
}

sub _parse_array_of_table {
    my ($self, $key) = @_;
    my @keys     = split /\./, $key;
    my $last_key = pop @keys;

    local $CONTEXT = $ROOT;
    for my $k (@keys) {
        if (exists $CONTEXT->{$k}) {
            $CONTEXT = ref $CONTEXT->{$k} eq 'ARRAY' ? $CONTEXT->{$k}->[-1] :
                       ref $CONTEXT->{$k} eq 'HASH'  ? $CONTEXT->{$k}       :
                       die "invalid structure. $key cannot be `Array of table`.";
        }
        else {
            $CONTEXT = $CONTEXT->{$k} ||= +{};
        }
    }

    $CONTEXT->{$last_key} = [] unless exists $CONTEXT->{$last_key};
    die "invalid structure. $key cannot be `Array of table`" unless ref $CONTEXT->{$last_key} eq 'ARRAY';
    push @{ $CONTEXT->{$last_key} } => $CONTEXT = {};

    $self->_parse_tokens();
}

sub _parse_value_token {
    my $self  = shift;
    my $token = shift;

    my ($type, $val) = @$token;
    if ($type eq TOKEN_COMMENT) {
        return; # pass through
    }
    elsif ($type eq TOKEN_INTEGER || $type eq TOKEN_FLOAT) {
        return 0+$val;
    }
    elsif ($type eq TOKEN_BOOLEAN) {
        return $self->inflate_boolean($val);
    }
    elsif ($type eq TOKEN_DATETIME) {
        return $self->inflate_datetime($val);
    }
    elsif ($type eq TOKEN_STRING) {
        return unescape_str($val);
    }
    elsif ($type eq TOKEN_ARRAY_BEGIN) {
        my @data;
        while (my $token = shift @TOKENS) {
            last if $token->[0] eq TOKEN_ARRAY_END;
            push @data => $self->_parse_value_token($token);
        }
        return \@data;
    }
    else {
        die "Unknown case. type:$type";
    }
}

sub inflate_datetime {
    my $self = shift;
    return $self->{inflate_datetime}->(@_);
}

sub inflate_boolean {
    my $self = shift;
    return $self->{inflate_boolean}->(@_);
}

1;
