#!/usr/bin/env ruby -w
# encoding: UTF-8
# frozen_string_literal: false

# tc_csv_writing.rb
#
# Created by James Edward Gray II on 2005-10-31.
require_relative "base"

class TestHBCSV::Writing < TestHBCSV
  extend DifferentOFS

  def test_writing
    [ ["\t",                      ["\t"]],
      ["foo,\"\"\"\"\"\",baz",    ["foo", "\"\"", "baz"]],
      ["foo,\"\"\"bar\"\"\",baz", ["foo", "\"bar\"", "baz"]],
      ["\"\"\"\n\",\"\"\"\n\"",   ["\"\n", "\"\n"]],
      ["foo,\"\r\n\",baz",        ["foo", "\r\n", "baz"]],
      ["\"\"",                    [""]],
      ["foo,\"\"\"\",baz",        ["foo", "\"", "baz"]],
      ["foo,\"\r.\n\",baz",       ["foo", "\r.\n", "baz"]],
      ["foo,\"\r\",baz",          ["foo", "\r", "baz"]],
      ["foo,\"\",baz",            ["foo", "", "baz"]],
      ["\",\"",                   [","]],
      ["foo",                     ["foo"]],
      [",,",                      [nil, nil, nil]],
      [",",                       [nil, nil]],
      ["foo,\"\n\",baz",          ["foo", "\n", "baz"]],
      ["foo,,baz",                ["foo", nil, "baz"]],
      ["\"\"\"\r\",\"\"\"\r\"",   ["\"\r", "\"\r"]],
      ["\",\",\",\"",             [",", ","]],
      ["foo,bar,",                ["foo", "bar", nil]],
      [",foo,bar",                [nil, "foo", "bar"]],
      ["foo,bar",                 ["foo", "bar"]],
      [";",                       [";"]],
      ["\t,\t",                   ["\t", "\t"]],
      ["foo,\"\r\n\r\",baz",      ["foo", "\r\n\r", "baz"]],
      ["foo,\"\r\n\n\",baz",      ["foo", "\r\n\n", "baz"]],
      ["foo,\"foo,bar\",baz",     ["foo", "foo,bar", "baz"]],
      [";,;",                     [";", ";"]],
      ["foo,\"\"\"\"\"\",baz",    ["foo", "\"\"", "baz"]],
      ["foo,\"\"\"bar\"\"\",baz", ["foo", "\"bar\"", "baz"]],
      ["foo,\"\r\n\",baz",        ["foo", "\r\n", "baz"]],
      ["\"\"",                    [""]],
      ["foo,\"\"\"\",baz",        ["foo", "\"", "baz"]],
      ["foo,\"\r.\n\",baz",       ["foo", "\r.\n", "baz"]],
      ["foo,\"\r\",baz",          ["foo", "\r", "baz"]],
      ["foo,\"\",baz",            ["foo", "", "baz"]],
      ["foo",                     ["foo"]],
      [",,",                      [nil, nil, nil]],
      [",",                       [nil, nil]],
      ["foo,\"\n\",baz",          ["foo", "\n", "baz"]],
      ["foo,,baz",                ["foo", nil, "baz"]],
      ["foo,bar",                 ["foo", "bar"]],
      ["foo,\"\r\n\n\",baz",      ["foo", "\r\n\n", "baz"]],
      ["foo,\"foo,bar\",baz",     ["foo", "foo,bar", "baz"]],
      [%Q{a,b},                   ["a", "b"]],
      [%Q{a,"""b"""},             ["a", "\"b\""]],
      [%Q{a,"""b"},               ["a", "\"b"]],
      [%Q{a,"b"""},               ["a", "b\""]],
      [%Q{a,"\nb"""},             ["a", "\nb\""]],
      [%Q{a,"""\nb"},             ["a", "\"\nb"]],
      [%Q{a,"""\nb\n"""},         ["a", "\"\nb\n\""]],
      [%Q{a,"""\nb\n""",},        ["a", "\"\nb\n\"", nil]],
      [%Q{a,,,},                  ["a", nil, nil, nil]],
      [%Q{,},                     [nil, nil]],
      [%Q{"",""},                 ["", ""]],
      [%Q{""""},                  ["\""]],
      [%Q{"""",""},               ["\"",""]],
      [%Q{,""},                   [nil,""]],
      [%Q{,"\r"},                 [nil,"\r"]],
      [%Q{"\r\n,"},               ["\r\n,"]],
      [%Q{"\r\n,",},              ["\r\n,", nil]] ].each do |test_case|
        assert_equal(test_case.first + $/, HBCSV.generate_line(test_case.last))
      end
  end

  def test_col_sep
    assert_equal( "a;b;;c\n", HBCSV.generate_line( ["a", "b", nil, "c"],
                                                 col_sep: ";" ) )
    assert_equal( "a\tb\t\tc\n", HBCSV.generate_line( ["a", "b", nil, "c"],
                                                    col_sep: "\t" ) )
  end

  def test_row_sep
    assert_equal( "a,b,,c\r\n", HBCSV.generate_line( ["a", "b", nil, "c"],
                                                   row_sep: "\r\n" ) )
  end

  def test_force_quotes
    assert_equal( %Q{"1","b","","already ""quoted"""\n},
                  HBCSV.generate_line( [1, "b", nil, %Q{already "quoted"}],
                                     force_quotes: true ) )
  end
end
