class String # :nodoc:
  # Equivalent to HBCSV::parse_line(self, options)
  #
  #   "HBCSV,data".parse_csv
  #     #=> ["HBCSV", "data"]
  def parse_csv(**options)
    HBCSV.parse_line(self, options)
  end
end
