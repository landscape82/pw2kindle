# FIXME rename to something else
package Pw2Kindle::Command::fetch;
use Moose;

use Term::ReadKey;
use Web::Query;
use WWW::Instapaper::Client;

use Pw2Kindle::Model::Article;
 
extends qw(MooseX::App::Cmd::Command);

has username => (
    isa => "Str",
    is  => "rw",
    required => 1,
    documentation => "instapaper username",
    traits => [ 'Getopt' ],
    cmd_aliases => 'u',
);

has dryrun => (
    isa => "Bool",
    is  => "rw",
    documentation => "no harm done. only outputs URL about to be sent to instapaper",

    # the following trait allows for the fancier options below
    traits    => [ 'Getopt' ],
    cmd_flag => 'dry-run',
    cmd_aliases   => 'd',
);

__PACKAGE__->meta->make_immutable;

sub abstract { "performs fetch operation only" }

sub execute {
    my ( $self, $opt, $args ) = @_;

    my $articles_ref = [ $self->fetch() ];
    return if $self->dryrun;

    my $password = $self->askPassword();
    my $instapaper_ws = WWW::Instapaper::Client->new(
        username        => $self->username(),
        password        => $password,
    );
    $self->publish($instapaper_ws, $articles_ref);   
}

=item fetch

=cut
# TODO I should ask szabgab how best to pull the stuff to avoid breakage
sub fetch {
    my ( $self ) = @_;

    print "Fetching Perl Weekly issue...\n";
    # TODO request szabgab a link like latest.html redirects or symlinks to latest issue
    # TODO option to provide issue number

    my @articles;
    wq('http://perlweekly.com/archive/13.html')
        # <p class=entry> then <a ...> </p>
        ->find('p.entry>a')
        ->each(sub {
            my $i = shift;
            my $article = Pw2Kindle::Model::Article->new( 
                title => $_->text,
                url => $_->attr('href'),
            );

            # TODO verbose instead of --dry-run
            printf("%d) %s\n", $i+1, $article->toString()) if $self->dryrun();

            push @articles, $article
    });
    print "Done!\n";
    return @articles;
}

=item publish

=cut
sub publish {
    my ($self, $instapaper_ws, $articles_ref) = @_;

    foreach my $article (reverse @$articles_ref) {
        my $result = $instapaper_ws->add(
            title => $article->title(),
            url   => $article->url(),
        );
        
        if (defined $result) {
            # TODO hide behind a verbose flag
            # print "URL added: ", $result->[0], "\n";  # http://instapaper.com/go/######
            print "Pushed article: ", $result->[1], "\n";
        }
        else {
            die "There was an error! Aborting operation. Error: " . $instapaper_ws->error . "\n";
        }
    }
    return 1;
}

=item askPassword

=cut
sub askPassword {
    my ($self) = @_;

    print "Please type in your instapaper password: ";
    ReadMode('noecho');
    my $password = ReadLine(0);
    chomp($password);
    ReadMode('restore');
    print "\n";

    return($password);
}

1;
