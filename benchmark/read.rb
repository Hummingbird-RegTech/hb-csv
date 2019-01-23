#!/usr/bin/env ruby

require 'hb_csv'
require 'benchmark/ips'

HBCSV.open("/tmp/file.csv", "w") do |csv|
  csv << ["player", "gameA", "gameB"]
  1000.times do
    csv << ['"Alice"', "84.0", "79.5"]
    csv << ['"Bob"', "20.0", "56.5"]
  end
end

Benchmark.ips do |x|
  x.report "HBCSV.foreach" do
    HBCSV.foreach("/tmp/file.csv") do |row|
    end
  end

  x.report "HBCSV#shift" do
    HBCSV.open("/tmp/file.csv") do |csv|
      while _line = csv.shift
      end
    end
  end

  x.report "HBCSV.read" do
    HBCSV.read("/tmp/file.csv")
  end

  x.report "HBCSV.table" do
    HBCSV.table("/tmp/file.csv")
  end
end
