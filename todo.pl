#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
use Pod::Usage ();
use File::Copy ();
use File::Spec ();
use POSIX      ();
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

my $ID_LENGTH = 5;
my $TODO_FILE = File::Spec->catfile( $ENV{HOME}, 'todo.txt' );
my $command   = shift || Pod::Usage::pod2usage(1);

Pod::Usage::pod2usage("ERROR: Unknown command '$command'")
    unless grep { $_ eq $command } (qw( add delete do done ls help ));

Pod::Usage::pod2usage(1) if $command eq 'help';

if ( $command eq 'delete' || $command eq 'do' ) {
    my $id = shift or Pod::Usage::pod2usage("Please provide a TODO id for $command");
    mark_todo( $id, 'C' ) if $command eq 'do';
    mark_todo( $id, 'D' ) if $command eq 'delete';

}
else {
    my $string = join ' ', @ARGV;
    if ( $command eq 'ls' ) {
        list_todos($string);
    }
    else {
        Pod::Usage::pod2usage("Please provide a TODO string for $command") unless $string;
        $command eq 'add' and add_todo($string);
        $command eq 'done' and add_todo( $string, done => 1 );
    }
}

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
        my ( $status, $id, $creation_date, $completion_date, @todo ) = split ':', $line, 5;
        my $todo = join ' ', @todo;
        push @todos,
            {
            creation_date   => $creation_date,
            completion_date => $completion_date,
            id              => $id,
            status          => $status,
            todo            => $todo
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
    my $todo = shift or die "add_todo() needs a TODO string";
    my %args = @_;

    my $done = $args{done};

    # Prepare TODO line.
    my $now = POSIX::strftime( '%Y-%m-%d_%H%M%S', localtime() );
    my $id = substr( Digest::MD5::md5_hex( $todo . $now ), 0, $ID_LENGTH );
    my $line = sprintf '%s:%s:%s:%s:%s',
        ( $done ? 'C' : 'T' ),
        $id,
        $now,
        ( $done ? $now : '' ),
        $todo;

    # Append this TODO to the file.
    open my $FILE, '>>', $TODO_FILE
        or die "ERROR: Unable to open '$TODO_FILE' for appending - $!";
    print $FILE $line, "\n";
    close $FILE or die "ERROR: Unable to close '$TODO_FILE' after appending - $!";

    print "Added $id - $todo\n";
}

=head2 B<mark_todo(C<ID>, C<Status>)>

Load the TODO file, and look for a TODO by ID. If found, then mark the TODO as
specified.

Prints out the work being done.

Expects:
    ID - The ID of the TODO to operate on.
    Status - The status to mark the TODO as.

Returns:
    None.

=cut

sub mark_todo {
    my $id     = shift or die "mark_todo() needs a TODO ID";
    my $status = shift or die "mark_todo() needs a TODO status";

    my @todos = read_todos();
    my $unsaved_changes;
    my $id_found;

    foreach my $todo (@todos) {
        if ( $todo->{id} eq $id ) {
            $id_found = 1;
            if ( $todo->{status} ne $status ) {
                $todo->{completion_date} = POSIX::strftime( '%Y-%m-%d_%H%M%S', localtime() );
                $todo->{status}          = $status;
                $unsaved_changes         = 1;
                last;
            }
        }
    }

    if ($unsaved_changes) {
        my $temp_file = "$TODO_FILE.tmp";
        open my $FILE, '>', $temp_file
            or die "ERROR: Unable to open '$temp_file' for writing - $!";
        foreach my $todo (@todos) {
            my $line = sprintf '%s:%s:%s:%s:%s',
                $todo->{status},
                $todo->{id}, $todo->{creation_date}, $todo->{completion_date}, $todo->{todo};
            print $FILE $line, "\n";
        }
        close $FILE or die "ERROR: Unable to close '$temp_file' after appending - $!";
        File::Copy::move( $temp_file, $TODO_FILE )
            or die "Unable to move '$temp_file' to '$TODO_FILE' - $!";
        print "TODO '$id' was marked as '$status'\n";
    }
    elsif ($id_found) {
        print "TODO '$id' was already marked as '$status'\n";
        return 0;
    }
    else {
        print "Unable to find TODO '$id' to mark as '$status'\n";
        return 0;
    }

    return 1;
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
