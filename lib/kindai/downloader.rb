# -*- coding: utf-8 -*-
module Kindai
  class Downloader
    attr_accessor :book
    attr_accessor :output_directory

    def self.new_from_book(book)
      raise TypeError, "#{book} is not Kindai::Book" unless book.is_a? Kindai::Book
      me = self.new
      me.book = book
      me
    end

    def download
      return if has_zip?
      create_directory
      pages = download_images
      if @test_mode
        Kindai::Util.logger.info "test done"
        return
      end
      # てきとう
      if @use_divide
        Kindai::Util.divide_opencv((1..pages).map{|i| path_at(i)})
        Kindai::Util.resize_all((1..pages).map{|i|
            [Kindai::Util.append_suffix(path_at(i), '0'),
              Kindai::Util.append_suffix(path_at(i), '1')]
          }.flatten, '600x800')
        Kindai::Util.delete_all((1..pages).map{|i| path_at(i)})
      end
      generate_pdf if @use_pdf
      generate_zip if @use_zip
    end

    def use_divide
      Kindai::Util.logger.info "dividing enabled"
      @use_divide = true
    end

    def use_pdf
      Kindai::Util.logger.info "pdf output enabled"
      @use_pdf = true
    end

    def use_zip
      Kindai::Util.logger.info "zip output enabled"
      @use_zip = true
    end

    def test_mode
      Kindai::Util.logger.info "test mode enabled"
      @test_mode = true
    end

    def directory_path
      default = [@book.author, @book.title].compact.join(' - ')
      default = @output_directory + '/' + default if @output_directory
      return default unless File.exists?(default)
      return default if File.directory?(default)
      (1..(1/0.0)).each{ |suffix|
        alter = [default, suffix].join('-')
        return alter unless File.exists?(default)
        return alter if File.directory?(default)
      }
    end

    def full_directory_path
      File.expand_path(directory_path)
    end

    def retry_count
      @retry_count || 3
    end

    def retry_count=(x)
      Kindai::Util.logger.info "retry_count = #{x}"
      @retry_count = x
    end

    def resize_option
      @resize_option
    end

    def resize_option=(x)
      Kindai::Util.logger.info "resize_option = #{x}"
      @resize_option = x
    end

    protected

    # TODO: output directory
    def path_at(i)
      "#{directory_path}/%03d.jpg" % i
    end

    def create_directory
      Dir.mkdir(directory_path) unless File.directory?(directory_path)
    end

    def download_images
      (1..(1/0.0)).each { |i|
        failed_count = 0
        begin
          if @test_mode
            File.delete(path_at(i)) if File.exists?(path_at(i))
            File.delete(Kindai::Util.append_suffix(path_at(i), '0')) if File.exists?(Kindai::Util.append_suffix(path_at(i), '0'))
            File.delete(Kindai::Util.append_suffix(path_at(i), '1')) if File.exists?(Kindai::Util.append_suffix(path_at(i), '1'))
          end
          # XXX
          if @use_divide and false
            next if has_divided_file_at(i)
            Kindai::Util.logger.info "downloading " + [@book.author, @book.title, "koma #{i}"].join(' - ')
            Kindai::Util.rich_download(@book.image_url_at(i), path_at(i)) unless has_whole_file_at(i)
            unless Kindai::Util.check_file path_at(i)
              File.delete path_at(i)
              raise 'failed to download'
            end
            files = Kindai::Util.divide(path_at(i))
            if @resize_option
              files.each{|path|
                Kindai::Util.logger.info "resize #{path}"
                system "convert -geometry #{@resize_option} '#{path}' '#{path}'"
              }
            end
          else
            next if has_whole_file_at(i)
            Kindai::Util.logger.info "downloading " + [@book.author, @book.title, "koma #{i}"].join(' - ')
            Kindai::Util.rich_download(@book.image_url_at(i), path_at(i))
            unless Kindai::Util.check_file path_at(i)
              File.delete path_at(i)
              raise 'failed to download'
            end
            if @resize_option
              files.each{|path|
                Kindai::Util.logger.info "resize #{path_at(i)}"
                system "convert -geometry #{@resize_option} '#{path_at(i)}' '#{path_at(i)}'"
              }
            end
          end
          return 1 if @test_mode
        rescue Interrupt => e
          Kindai::Util.logger.error "#{e.class}: #{e.message}"
          exit 1
        rescue Exception, TimeoutError => e
          failed_count += 1
          Kindai::Util.logger.warn "failed (#{failed_count}/#{retry_count}) #{e.class}: #{e.message}"
          if failed_count >= retry_count
            Kindai::Util.logger.info "done"
            return i-1
          else
            Kindai::Util.logger.info "sleep and retry"
            sleep 3
            retry
          end
        end
      }
    end

    def has_zip?
      File.exist?(full_directory_path + '.zip')
    end

    def has_whole_file_at(i)
      File.size?(path_at(i))
    end

    def has_divided_file_at(i)
      File.size?(Kindai::Util.append_suffix(path_at(i), '0')) && File.size?(Kindai::Util.append_suffix(path_at(i), '1'))
    end

    def generate_pdf
      Kindai::Util.generate_pdf(full_directory_path, [@book.author, @book.title].compact.join(' - '))
    end

    def generate_zip
      Kindai::Util.generate_zip(full_directory_path)
    end
  end
end
