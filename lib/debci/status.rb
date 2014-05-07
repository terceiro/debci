module Debci

  class Status < Struct.new(:suite, :architecture, :run_id, :package, :version, :date, :status, :blame, :previous_status, :duration_seconds, :duration_human, :message)

    class << self

      def from_file(path)
        status = new
        return status unless File.exists?(path)
        File.open(path, 'r') do |f|
          data = JSON.load(f)
          status.run_id = data['run_id']
          status.package = data['package']
          status.version = data['version']
          status.date =
            begin
              Time.parse(data.fetch('date', 'unknown') + ' UTC')
            rescue ArgumentError
              nil
            end
          status.status = data.fetch('status', :unknown).to_sym
          status.previous_status = data.fetch('previous_status', :unknown).to_sym
          status.duration_seconds =
            begin
              Integer(data.fetch('duration_seconds', 0))
            rescue ArgumentError
              nil
            end
          status.duration_human = data['duration_human']
          status.message = data['message']
        end
        status
      end

    end
  end

end
