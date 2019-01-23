class Array # :nodoc:
  # Equivalent to HBCSV::generate_line(self, options)
  #
  #   ["HBCSV", "data"].to_csv
  #     #=> "HBCSV,data\n"
  def to_csv(**options)
    HBCSV.generate_line(self, options)
  end
end
