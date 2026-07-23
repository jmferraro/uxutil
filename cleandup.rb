#!/usr/bin/env ruby

require 'optparse'
require 'fileutils'
require 'tempfile'

VERSION = "0.3.0"
PROG = File.basename($0)

# defaults
opts = {
  both:       false,
  link:       false,
  no_exec:    false,
  no_hdr:     false,
  no_recurse: false,
  quiet:      false,
  verbose:    0
}

# parse the command line
parser = OptionParser.new do |o|
  o.banner = "Usage: #{PROG} [options] [dir1 dir2]"
  o.separator ""
  o.separator "Deletes files from dir2 that are duplicates of files in dir1."
  o.separator ""
  o.separator "Options:"
  o.on("-B", "--both",       "delete both copies if duplicate is found")   { opts[:both]       = true }
  o.on("-L", "--link",       "follow symlinks while walking dir tree")     { opts[:link]       = true }
  o.on(      "--no_hdr",     "ignore $Header and $Id lines in source")     { opts[:no_hdr]     = true }
  o.on("-n", "--no_execute", "dry run, show what would be deleted")        { opts[:no_exec]    = true }
  o.on("-q", "--quiet",      "quiet")                                      { opts[:quiet]      = true }
  o.on("-R", "--no_recurse", "do not recurse directory tree")              { opts[:no_recurse] = true }
  o.on("-v", "--verbose",    "verbose (multiple = more verbose)")          { opts[:verbose]   += 1 }
  o.on("-V", "--version",    "print version number and exit")              { puts "#{PROG} - version #{VERSION}"; exit }
  o.on("-h", "--help",       "show this help text")                        { puts o; exit }
end

begin
  parser.order!
rescue OptionParser::ParseError => e
  $stderr.puts e.message
  $stderr.puts parser
  exit 1
end

opts[:verbose] = 0 if opts[:quiet]

# positional arguments
if ARGV.length > 0
  unless ARGV.length == 2
    $stderr.puts "Incorrect number of arguments"
    exit 1
  end
  sav, del = ARGV
else
  sav, del = "..", "."
  opts[:no_recurse] = true
end

sav = sav.sub(/[\\\/]+$/, '')
del = del.sub(/[\\\/]+$/, '')

abort "Error: sav directory is empty after stripping" if sav.empty?
abort "Error: del directory is empty after stripping" if del.empty?

$errors = 0

# =============================================================================

def read_dir(dir)
  Dir.children(dir)
rescue SystemCallError => e
  puts "Error: cannot open #{dir}: #{e.message}"
  $errors += 1
  []
end

# =============================================================================

def files_identical?(file1, file2)
  FileUtils.identical?(file1, file2)
end

# =============================================================================

def filter_hdr(infile, out_fh)
  File.foreach(infile) do |line|
    next if line.include?('$Header')
    next if line.include?('$Id')
    out_fh.write(line)
  end
rescue SystemCallError => e
  puts "Error: cannot read #{infile}: #{e.message}"
  $errors += 1
end

# =============================================================================

def my_cmp(file1, file2, opts)
  if opts[:no_hdr]
    tmp1 = Tempfile.new('cleandup-')
    tmp2 = Tempfile.new('cleandup-')
    begin
      filter_hdr(file1, tmp1)
      filter_hdr(file2, tmp2)
      tmp1.close
      tmp2.close
      return FileUtils.identical?(tmp1.path, tmp2.path)
    ensure
      tmp1.close!
      tmp2.close!
    end
  else
    puts "Executing: compare(#{file1}, #{file2})" if opts[:verbose] > 1
    return FileUtils.identical?(file1, file2)
  end
end

# =============================================================================

def is_same?(file1, file2)
  s1 = File.stat(file1)
  s2 = File.stat(file2)
  s1.dev == s2.dev && s1.ino == s2.ino
end

# =============================================================================

def clean_dir(dir, sav, del, opts)
  unless File.readable?(dir)
    puts "Error: unreadable dir: #{dir}"
    $errors += 1
    return
  end

  files = read_dir(dir)
  files.each do |file|
    fullpath = "#{dir}/#{file}"
    if File.directory?(fullpath)
      next if !opts[:link] && File.symlink?(fullpath)  # skipping symlinks?
      next if opts[:no_recurse]                        # no recursion
      clean_dir(fullpath, sav, del, opts)              # recurse
    else
      path = fullpath
      puts "Checking: #{path}" if opts[:verbose] > 1
      name = path[(sav.length + 1)..]                  # extract relative path
      seek = "#{del}/#{name}"                          # generate posdup name
      next unless File.exist?(seek)                    # skip if it doesn't exist
      next if File.directory?(seek)                    # skip if it's a directory
      puts "Cmparing: #{seek}" if opts[:verbose] > 2
      identical = my_cmp(path, seek, opts)
      if identical
        same = is_same?(path, seek)
        next if same && !opts[:both]                   # don't delete only copy!
        puts "Deleting: #{seek}" if opts[:verbose] > 0
        unless opts[:no_exec]
          File.delete(seek) rescue (puts "Error: cannot delete #{seek}: #{$!}"; $errors += 1)
        end
        if opts[:both] && !same
          puts "Deleting: #{path}" if opts[:verbose] > 1
          unless opts[:no_exec]
            File.delete(path) rescue (puts "Error: cannot delete #{path}: #{$!}"; $errors += 1)
          end
        end
      end
    end
  end

  # clean up empty directories
  return if dir == sav
  relpath = dir[(sav.length + 1)..]

  # remove empty del directory
  chk = "#{del}/#{relpath}"
  if File.exist?(chk)
    if read_dir(chk).empty?
      puts "Removing: #{chk}/" if opts[:verbose] > 0
      unless opts[:no_exec]
        Dir.rmdir(chk) rescue (puts "Error: cannot rmdir #{chk}: #{$!}"; $errors += 1)
      end
    end
  end

  # remove empty sav directory when --both is active
  if opts[:both] && File.exist?(dir)
    if read_dir(dir).empty?
      puts "Removing: #{dir}/" if opts[:verbose] > 0
      unless opts[:no_exec]
        Dir.rmdir(dir) rescue (puts "Error: cannot rmdir #{dir}: #{$!}"; $errors += 1)
      end
    end
  end
end

# =============================================================================

clean_dir(sav, sav, del, opts)
exit($errors > 0 ? 1 : 0)

# ------------------------------- END OF FILE ---------------------------------
