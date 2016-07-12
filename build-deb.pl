#!/usr/bin/perl
#

use strict;
use warnings;
use Getopt::Long;
use File::Copy::Recursive qw( fcopy dircopy pathmk pathrmdir );

my @modes = (
    qw(
      all
      )
);

my ( $o_mode, $o_root, $o_version );

GetOptions(
    "m|mode:s"    => \$o_mode,
    "r|root:s"    => \$o_root,
    "v|version:s" => \$o_version,
);

if ( !$o_version ) {
    print "Please pass in a version number to compile, expecting something like 1.0.0\n";
    exit(1);
}

if ( !$o_mode ) {
    $o_mode = "all";
}

if ( !$o_root ) {
    $o_root = "/opt/livestatus-api";
}
elsif ( $o_root =~ /^\/$/ ) {
    print "Unable to use / as install location, expecting like /opt/brood\n";
    exit(1);
}
elsif ( $o_root =~ /\/$/ ) {
    $o_root =~ s/\/$//;
}

if ( !grep $o_mode eq $_, @modes ) {
    print "Argument passed doesn't match an expected value: $o_mode :: "
      . join( ", ", @modes ) . "\n";
    exit(1);
}

if ( $o_mode eq "all" ) {
    print "Building All Packages...\n";
    build_core();
}
else {
    print "Hey, how'd you get here???\n";
    exit(1);
}

sub build_core {
    print "Building Core Package...\n";
    pathmk( "_debian/$o_root/lapi", "_debian/etc/init.d" );
    pathmk( "_debian/var/log/livestatus-api" );
    dircopy( "lapi/*", "_debian/$o_root/lapi/" );
    fcopy( "misc/init.script", "_debian/etc/init.d/lapi-dancer" );
    chmod oct("0755"), "_debian/etc/init.d/lapi-dancer";
    createdebianfiles( $o_version, 'livestatus-api' );
    qx{fakeroot dpkg -b _debian livestatus-api-$o_version.deb};
    pathrmdir("_debian");
}

sub createdebianfiles {
    my ( $o_version, $package ) = (@_);
    pathmk("_debian/DEBIAN");
    createcontrol( $o_version, $package );
    createpreandpost($package);
    pathmk("_debian/usr/share/doc/$package");
    fcopy( "LICENSE", "_debian/usr/share/doc/$package/copyright" );
    createmd5s();
}

sub createcontrol {
    my ( $o_version, $package ) = (@_);
    open my $fh, ">", "_debian/DEBIAN/control"
      or die "Unable to open file: _debian/DEBIAN/control :: $!";
    print $fh "Package: $package\n";
    print $fh "Version: $o_version\n";
    print $fh "Section: unknown\n";
    print $fh "Priority: optional\n";
    print $fh "Architecture: all\n";
    print $fh "Maintainer: Matt West <mwest\@pinterest.com>\n";

    if ( $package eq 'livestatus-api' ) {
        print $fh
"Description: Livestatus API provides an API Layer for communicating with LiveStatus across clusters\n";
    }
    close $fh;
}

sub createpreandpost {
    my $package = shift;
    if ( $package eq 'livestatus-api' ) {
    }
    chmod oct("0755"), "_debian/DEBIAN/postinst"
      unless ( !-e "_debian/DEBIAN/postinst" );
    chmod oct("0755"), "_debian/DEBIAN/prerm"
      unless ( !-e "_debian/DEBIAN/prerm" );
}

sub createmd5s {
    open my $fh, ">", "_debian/DEBIAN/md5sums"
      or die "Unable to open file: _debian/DEBIAN/md5sums :: $!";
    open CMD,
      "find _debian/ -not -path \"*/DEBIAN/*\" -type f -exec md5sum {} \\; |"
      or die "Failed: $!";
    while ( my $line = <CMD> ) {
        $line =~ s/_debian\///;
        print $fh $line;
    }
    close($fh);
}

