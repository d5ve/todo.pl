#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
use Pod::Usage ();
use File::Spec ();
use POSIX ();
use Digest::MD5;

=head1 NAME

todo.pl - Yet another simple text-based TODO script

=head1 SYNOPSIS

    todo.pl <command> [ID|filter]

        Commands:
            add     <String>    - Add a new TODO.
            delete  <ID>        - Mark an existing TODO as deleted - not as completed.
            do      <ID>        - Mark an existing TODO as completed.
            done    <String>    - Add a new TODO and immediately mark it as completed (add + do).
            ls      [String]    - Print list of TODOs, optionally matching filter string.
            help                - Print help text.

        Example:
            # Add a new TODO to the file.
            todo.pl add Pick up bananas on way home.

            # List all outstanding TODOs.
            todo.pl ls

            # List all outstanding TODOs containing the string Monday.
            todo.pl ls Monday

            # Mark a TODO as completed.
            todo.pl do 4a8a

            # Add a new, completed TODO.
            todo.pl done Cancel car insurance.

=cut

my $ID_LENGTH = 4;
my $TODO_FILE = File::Spec->catfile( $ENV{HOME}, 'todo.txt' );
my $command = shift || Pod::Usage::pod2usage(1);

Pod::Usage::pod2usage("ERROR: Unknown command '$command'")
    unless grep { $_ eq $command } (qw( add delete do done ls help ));

Pod::Usage::pod2usage(1) if $command eq 'help';

my $id;
my $string;

if ( $command eq 'delete' || $command eq 'do' ) {
    $id = shift or Pod::Usage::pod2usage("Please provide a TODO id for $command");
}
else {
    $string = join ' ', @ARGV;
}

$command eq 'ls' and list_todos($string);
$command eq 'add' and add_todo($string);
$command eq 'done' and add_todo($string, done => 1);

exit;

=head1 SUBROUTINES

=head2 B<list_todos(C<filter string>)>

Print out the current list of TODOs, filtering by any string passed in.

Expects:
    Filter string, an optional string to filter TODOs by.

Returns:
    None.

=cut

sub list_todos {
    my $filter_string = shift || '';

    my $todos = read_todos();

    foreach my $todo ( read_todos() ) {
        next unless $todo->{status} eq 'T';
        print "$todo->{id}\t$todo->{todo}\n"
            if $filter_string eq '' || $todo->{todo} =~ m{\Q$filter_string\E}ixms;
    }
}

=head2 B<read_todos()>

Read the contents of the TODO file from disk, then parse each into the
constituent fields.

Expects:
    None.

Returns:
    List of hash refs, each containing a TODO.

=cut

sub read_todos {

    if ( !-f $TODO_FILE ) {
        return ();
    }

    open my $FILE, '<', $TODO_FILE
        or die "ERROR: Unable to open '$TODO_FILE' for reading - $!";

    my @todos;

    foreach my $line (<$FILE>) {
        chomp $line;
        my ( $status, $id, $creation_date, $completed_date, $todo ) = split ':', $line;

        push @todos,
            {
            completed_date => $completed_date,
            id             => $id,
            status         => $status,
            todo           => $todo
            };
    }

    close $FILE or die "ERROR: Unable to close '$TODO_FILE' after reading - $!";

    return @todos;

}

=head2 B<add_todo(C<TODO string>, C<%args>)>

Add a new TODO to the file. Optionally mark it as already completed.

This appends a new line to the TODO file, setting the ID, status, and dates as
required.  The normal status is C<T>. The creation date field is set to the
current datetime. If the C<done> argument is passed, then the status is set to
C<C>, and the completion date is also set to the current datetime.

The new ID, status, and TODO string are printed to STDOUT.

Expects:
    TODO string - The text of the TODO.
    %ARGS       - An optional hash of arguments.
                  Currently:
                    done => 0|1 - Mark this TODO as completed immediately.
Returns:
    None.

=cut

sub add_todo {
    my $todo = shift or Pod::Usage::pod2usage("Please supply a TODO string to add.");
    my %args = @_;

    my $done = $args{done};

    # Prepare TODO line.
    my $id = substr(Digest::MD5::md5_hex($todo), 0, $ID_LENGTH);
    my $now = POSIX::strftime('%Y-%m-%d_%H%M%S', localtime());
    my $line = sprintf '%s:%s:%s:%s:%s',
        ($done ? 'C' : 'T'),
        $id,
        $now,
        ($done ? $now : ''),
        $todo;

    # Append this TODO to the file.
    open my $FILE, '>>', $TODO_FILE
        or die "ERROR: Unable to open '$TODO_FILE' for appending - $!";
    print $FILE $line, "\n";
    close $FILE or die "ERROR: Unable to close '$TODO_FILE' after appending - $!";
}

=head1 DESCRIPTION

todo.pl is a simple (core modules only) perl script for maintaining a todo.txt
file. It offers a few commands to add lines, and to mark those lines as deleted
or completed.

The text file is in the following format:

    Status:ID:Creation date:Update date:Task string

With each task being on a single line.

The status codes currently are:

    T - TODO, not completed.
    C - Completed.
    D - Deleted without being completed.

No code has been written yet, just this README.

=head1 SEE ALSO

=over 4

=item * todo.txt by Gina Trapani, L<http://todotxt.com/>

B<todo.txt> was the main inspiration for B<todo.pl>, and I used it for a couple of
years. However, there were a couple of things that I couldn't get behaving as I
wanted, and bash scripting isn't a strong point of mine. B<todo.pl> has a subset
of the functionality of B<todo.txt>, but it's the subset I used or wanted.

=item * B<t-> by Colin Wright, L<http://www.penzba.co.uk/t-/>

B<t-> was my inspiration for actually writing my own script. It is a tiny
python script offering the minimum functionlity that the author needed. I have
never used it, but read the source and figured I could write something as
simple in Perl which did exactly what I wanted.

=back

=head1 AUTHOR

Dave Webb L<github@d5ve.com>

=head1 LICENSE

todo.pl is free software. It comes without any warranty, to the extent permitted
by applicable law.

todo.pl is released under the I<WTFPL Version 2.0> license - L<http://sam.zoy.org/wtfpl/COPYING>

=cut
