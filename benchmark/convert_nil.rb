#!/usr/bin/env ruby

require "csv"

require "benchmark/ips"

csv_text = <<HBCSV
foo,bar,,baz
hoge,,temo,
roo,goo,por,kosh
HBCSV

convert_nil = ->(s) {s || ""}

Benchmark.ips do |r|
  r.report "not convert" do
    HBCSV.parse(csv_text)
  end

  r.report "converter" do
    HBCSV.parse(csv_text, converters: convert_nil)
  end

  r.report "option" do
    HBCSV.parse(csv_text, nil_value: "")
  end

  r.compare!
end
