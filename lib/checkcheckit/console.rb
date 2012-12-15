require 'ostruct'

class CheckCheckIt::Console
  attr_accessor :list_dir
  attr_accessor :out_stream, :in_stream

  def initialize(opts = {})
    @out_stream = opts[:out_stream] || $stdout
    @in_stream  = opts[:in_stream]  || $stdin
  end

  def puts(text = '')
    @out_stream.puts text
  end

  def print(text = '')
    @out_stream.print text
  end

  def run!(args = [])
    @options  = Lucy::Goosey.parse_options(args)
    @list_dir = File.expand_path(@options.fetch('home', '~/checkcheckit'))

    if args.length == 0
      puts "No command given"
    else
      method = args.shift
      if respond_to? method
        send method, args
      else
        puts "did not understand: #{method}"
      end
    end
  end

  def dir
    File.expand_path(@list_dir)
  end

  def step_through_list(list)
    results = Array.new(list.steps.length, false)

    list.steps.each_with_index do |step, i|
      puts "#{fmt_results(results)} Step #{i+1}: #{step.name}"
      puts step.body unless step.body.empty?

      check, notes = nil
      begin
        print "Check: "
        case input = in_stream.gets
        when /^[y|+]$/ || ''
          check = true
        when /^[n|-]$/
          check = false
        else
          check = true
        end

        if @options['notes'] || @options['n']
          print "Notes: "
          notes = in_stream.gets
        end
      rescue Interrupt => e
        puts "\nGoodbye!"
        exit 1
      end

      results[i] = {
        step: i + 1,
        name: step.name,
        body: step.body,
        check: check,
        result: check ? 'CHECK' : 'FAIL',
        status: check ? 1 : 0,
        notes: notes
      }

      puts
    end

    msg = results.all? { |r| r } ? "Done" : "Issues"
    puts "#{fmt_results(results)} #{msg}"
    save_results(list, results)
  end

  def save_results(list,results)
    report = {
      'list-name' => list.name,
      'results' => results
    }
  end

  def start(args)
    target = args.first
    hit = Dir[dir + '/*/*'].find{ |fname| fname.include? target }
    if hit
      step_through_list(List.new(hit))
    else
      puts "Could not find checklist via: #{target}"
    end
  end

  def list(args)
    puts "# Checklists\n"
    Dir[dir + '/*'].each do |dir|
      team = File.basename dir
      puts team
      Dir[dir + '/*'].each do |file|
        puts "  " + List.new(file).name
      end
    end
  end

  private
  def fmt_results(results)
    keys = results.map do |result|
      if result
        result[:check] ? '+' : '-'
      else
        '.'
      end
    end
    "|#{keys.join}|"
  end
end
