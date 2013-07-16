require 'pdf/margins/issue'
require 'pdf/margins/errors'
require 'chunky_png'
require 'oily_png'
require 'tmpdir'

module PDF
  module Margins
    class Checker

      MM_TO_PTS = 2.83464567
      DEFAULT_RESOLUTION = 72
      # If we find that we need higher resolution for better precision then we
      # can adjust the SCALE_MULTIPLIER at the cost of speed.
      SCALE_MULTIPLIER = 1 
      RESOLUTION = DEFAULT_RESOLUTION * SCALE_MULTIPLIER

      attr_reader :file_path, :top_margin, :right_margin, :bottom_margin, :left_margin, :spreads

      # Dimensions are in mm, to be converted to PDF points later. Pass spreads
      # as true to check left and right margins of spreads, not pages.
      def initialize(file_path, top_margin, right_margin, bottom_margin, left_margin, spreads=false)
        @file_path     = file_path
        @top_margin    = top_margin
        @right_margin  = right_margin
        @bottom_margin = bottom_margin
        @left_margin   = left_margin
        @spreads       = spreads
      end

      def issues
        temp_dir_path = Dir.mktmpdir("pdf_margins")

        begin
          # This produces greyscale PNGs - we throw the colour away because we
          # don't need it to check for margins.
          system("mudraw -g -b 0 -r #{RESOLUTION} -o #{temp_dir_path}/%d.png #{file_path}") || raise(PDF::Margins::MuDrawCommandError)

          issues = []

          files = Dir.glob("#{temp_dir_path}/*.png")
          # ensure the files are sorted naturally
          files = files.sort_by{ |f| f.split('/').last.to_i }

          files.each_with_index do |png_path, index|
            image = ChunkyPNG::Image.from_file(png_path)
            page_number = index + 1

            if dirty_top_margin?(image, top_margin)
              issues << Issue.new(page_number, :top)
            end

            if dirty_bottom_margin?(image, bottom_margin)
              issues << Issue.new(page_number, :bottom)
            end

            if (!spreads || page_number % 2 == 0) && dirty_left_margin?(image, left_margin)
              issues << Issue.new(page_number, :left)
            end
            
            if (!spreads || page_number % 2 != 0) && dirty_right_margin?(image, right_margin)
              issues << Issue.new(page_number, :right)
            end
          end

        ensure
          FileUtils.remove_entry(temp_dir_path)
        end

        return issues
      end

      private

      def mm_to_pixels(mm)
        (mm * MM_TO_PTS * SCALE_MULTIPLIER).floor
      end

      def dirty_top_margin?(image, mm)
        px = mm_to_pixels(mm)
        dirty_pixels?(image, 0, 0, image.width, px)
      end

      def dirty_left_margin?(image, mm)
        px = mm_to_pixels(mm)
        dirty_pixels?(image, 0, 0, px, image.height)
      end

      def dirty_right_margin?(image, mm)
        px = mm_to_pixels(mm)
        offset = image.width - px - 1
        dirty_pixels?(image, offset, 0, px, image.height)
      end

      def dirty_bottom_margin?(image, mm)
        px = mm_to_pixels(mm)
        offset = image.height - px - 1
        dirty_pixels?(image, 0, offset, image.width, px)
      end

      def dirty_pixels?(image, x, y, width, height)
        white = ChunkyPNG::Color::WHITE
        found_dirty_pixel = false

        width.times do |x_offset|
          break if found_dirty_pixel

          height.times do |y_offset|
            x_position = x + x_offset
            y_position = y + y_offset

            if image[x_position, y_position] != white 
              found_dirty_pixel = true
              break
            end
          end
        end

        return found_dirty_pixel
      end

    end
  end
end

