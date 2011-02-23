#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
use Pod::Usage ();
use File::Spec ();

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

my $TODO_FILE = File::Spec->catfile($ENV{HOME}, 'todo.txt');
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
        print "$todo->{contents}\n" if $todo->{contents} =~ m{\Q $filter_string \E}ixms;
    }
}

=head2 B<read_todos()>

Read the contents of the todo file from disk, filtering for active TODOs only.
Then parse each into the constituent fields.

Expects:
    None.

Returns:
    Reference to a list of hashes.

=cut

sub read_todos {

    return ();

}


=head1 DESCRIPTION

todo.pl is a simple (core modules only) perl script for maintaining a todo.txt
file. It offers a few commands to add lines, and to mark those lines as deleted
or completed.

The text file is in the following format:

    Status:Creation date:Update date:Task string

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
never used it, but read the source and figured I could do the same in perl
easily.

=back

=head1 AUTHOR

Dave Webb L<github@d5ve.com>

=head1 LICENSE

todo.pl is free software. It comes without any warranty, to the extent permitted
by applicable law.

todo.pl is released under the I<WTFPL Version 2.0> license - L<http://sam.zoy.org/wtfpl/COPYING>

=cut
