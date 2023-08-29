# App::ChmWeb

This is a tool for generating browsable web pages from CHM (Microsoft Compiled HTML Help) files.

Broadly speaking, it works by unpacking the chm with 7zip and then altering/generating HTML files to fix any broken links, ActiveX controls or other things that don't work in normal browsers.

## Usage examples

    # Process a single CHM file
    $ chmweb <file.chm> <output-directory>
    
    # Combine several CHM files into the same set of pages
    $ chmweb <file1.chm> <file2.chm> <output-directory>
    
    # Process a set of combined CHM files
    $ chmweb <MSDNxxx.chw> <output-directory>

## Dependencies

The following Perl modules are required to use this package:

 * File::Basename
 * HTML::Entities
 * IO::Compress::Gzip
 * JSON
 * SGML::Parser::OpenSP
 * Sys::Info::Base
 * XML::Parser

All of the above modules are available on Debian (or included in the core modules):

    $ sudo apt-get install libhtml-parser-perl libjson-perl libsgml-parser-opensp-perl libsys-info-base-perl libxml-parser-perl

The `7z` command must also be installed.

## How to run directly from the source directory

    $ perl -Ilib bin/chmweb ...

## How to install the package

    $ perl Build.PL
    $ sudo ./Build install
