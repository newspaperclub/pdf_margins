require 'test/unit'
require 'pdf/margins'
require 'mocha/setup'

class Test::Unit::TestCase

  def pdf_path(filename)
    File.join(File.dirname(__FILE__), 'pdfs', filename)
  end

end
