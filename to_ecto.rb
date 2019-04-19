#!/usr/bin/env ruby

require 'optparse'

UPDATED_AT = 'updated_at'
DEFAULT_INS = 'inserted_at'
$args = {:PRX => [], :ins => DEFAULT_INS, :dt => 'utc_datetime'}
OptionParser.new do |opt|
  opt.on('-i', '--input FILE', 'Your schema.rb') { |o| $args[:file_in] = o }
  opt.on('-o', '--output DIR', 'Where models will be written') { |o| $args[:dir_out] = o }
  opt.on('-n', '--namespace NS', 'Your namespace') { |o| $args[:ns] = o }
  opt.on('-p', '--prefixes PREFIXES', 'Comma separated table name prefixes to turn into subnamespaces') { |o| $args[:prx] = o.split(',') }
  opt.on('-P', '--not-prefixes PREFIXES', 'Comma separated table name prefixes to not turn into subnamespaces') { |o| $args[:PRX] = o.split(',') }
  opt.on('-c', '--inserted_at FIELD', 'Name of inserted_at timestamp field') { |o| $args[:ins] = o }
  opt.on('-d', '--datetime TYPE', 'What to replace RoR `datetime` with') { |o| $args[:dt] = o }
end.parse!

abort 'Missing input file' unless $args[:file_in]
abort 'Missing output directory' unless $args[:dir_out]
abort 'Missing namespace' unless $args[:ns]

$tables = {}

module ActiveRecord
  module Schema
    def self.define(_opts, &block)
      block.call()
    end
  end
end

def camelize(str)
  str.split('_').map(&:capitalize).join()
end

def singular(str)
  s = str.dup
  if str.end_with?('series')
    # historical reasons
    s.delete_suffix!('s')
  elsif str.end_with?('ties')
    # abilities => ability
    s.delete_suffix!('ies') + 'y'
  elsif str.end_with?('oes')
    # heroes => hero
    s.delete_suffix!('es')
  elsif str.end_with?('ches')
    # matches => match
    s.delete_suffix!('es')
  elsif str.end_with?('sses')
    # processes => process
    s.delete_suffix!('es')
  elsif str.end_with?('s')
    # teams => team
    s.delete_suffix!('s')
  else
    s
  end
end

def modulize(str, scope=nil)
  s = singular(str)
  pref = ''
  if scope == nil
    ss = s.split('_')
    if $args[:prx].include?(ss[0])
      pref = camelize(ss[0]) + '.'
      s = s.delete_prefix!(ss[0])
    end
  else
    ss = scope.split('_')
    if !$args[:PRX].include?(s) && $args[:prx].include?(ss[0])
      pref = camelize(ss[0]) + '.'
    end
  end
  $args[:ns] + '.' + pref + camelize(s)
end

class Table
  def initialize(name, opts=[])
    @name = name
    @opts = opts
    @fields = {}
    @belongs = {}
  end

  def dump
    puts "defmodule #{modulize(@name)} do"
    puts "  schema \"#{@name}\" do"
    if @fields.key?($args[:ins]) && @fields.key?(UPDATED_AT)
      # delete one of the two here so the other one can be replaced below
      @fields.delete($args[:ins])
    end
    @fields.each do |field, details|
      if field.end_with?('_id')
        trimmed = field.dup.delete_suffix!('_id')
        puts "    belongs_to(:#{trimmed}, #{modulize(trimmed,@name)})"
      elsif field == UPDATED_AT
        if $args[:ins] == DEFAULT_INS
          puts '    timestamps()'
        else
          puts "    timestamps(inserted_at: :#{$args[:ins]})"
        end
      else
        if details[:ty] == :datetime
          puts "    field(:#{field}, :#{$args[:dt]})"
        else
          puts "    field(:#{field}, :#{details[:ty]})"
        end
      end
    end
    @belongs.each do |target, opts|
      puts "    belongs_to(:#{singular(target)}, #{modulize(target,@name)})"
    end
    puts '  end'
    puts 'end'
  end

  def index(field, opts=[])
    # pass
  end

  [
    :bigint,
    :boolean,
    :datetime,
    :float,
    :inet,
    :integer,
    :json,
    :jsonb,
    :string,
    :text,
    :uuid,
  ].each do |ty|
    define_method(:"#{ty}") do |field, opts=[]|
      @fields[field] = {ty: __method__, opts: opts}
      return
    end
  end

  def belongs_to(target, opts)
    @belongs[target] = opts
  end
end

def enable_extension(name)
  # pass
end

def create_table(name, opts, &block)
  table = Table.new(name, opts)
  block.call(table)
  $tables[name] = table
  return
end

def add_foreign_key(table, target, opts=[])
  # https://haughtcodeworks.com/blog/software-development/ecto-schemas-on-rails/
  if !$tables.key?(table)
    # FIXME? https://stackoverflow.com/a/51479789/1418165
    puts "Skipping fk from #{table} to #{target} as table wasn't dumped!"
    return
  end
  $tables[table].belongs_to(target, opts)
  return
end


require $args[:file_in]

$tables.each do |name, table|
  puts table.dump()
end
puts $tables.length
