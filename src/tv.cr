require "sdl"
require "./sdl_ext"

class ColorMaker
  def initialize(@delay : Int32)
    @r = 0
    @g = 255
    @b = 0
    @time = 0
    @state = :blue_up
  end

  def next
    @time += 1
    if @time == @delay
      next_state
      @time = 0
    end
  end

  def next_state
    case @state
    when :green_up
      @g += 1
      @state = :red_down if @g == 255
    when :red_down
      @r -= 1
      @state = :blue_up if @r == 0
    when :blue_up
      @b += 1
      @state = :green_down if @b == 255
    when :green_down
      @g -= 1
      @state = :red_up if @g == 0
    when :red_up
      @r += 1
      @state = :blue_down if @r == 255
    when :blue_down
      @b -= 1
      @state = :green_up if @b == 0
    end
  end

  def black_color
    make_alpha_color(0.25)
  end

  def dark_color
    make_alpha_color(0.5)
  end

  def light_color
    make_alpha_color(1.0)
  end

  def make_alpha_color(multiplier)
    rand = Random::DEFAULT.next_int
    r = ((rand >> 16) % 256).to_i
    g = ((rand >> 8) % 256).to_i
    b = (rand % 256).to_i
    r = saturate_color(r, @r, multiplier)
    g = saturate_color(g, @g, multiplier)
    b = saturate_color(b, @b, multiplier)
    make_color r, g, b, 0
  end

  def saturate_color(random, component, multiplier)
    Math.min(random, (component * multiplier).to_i)
  end

  def make_color(r, g, b, a)
    (b << 24) + (g << 16) + (r << 8) + a
  end
end

class Rectangle
  def initialize(@x : Int32, @y : Int32, @light : Bool)
  end

  def light?
    @light
  end

  def contains?(x, y)
    @x == x && @y == y
  end
end

def parse_rectangles
  rects = [] of Rectangle
  lines = File.read("#{__DIR__}/tv.txt").split('\n').map { |line| line.rstrip }
  lines.each_with_index do |line, y|
    x = 0
    line.each_char do |c|
      if c == 'x'
        rects << Rectangle.new(x, y, true)
      elsif c == '.'
        rects << Rectangle.new(x, y, false)
      end
      x += 1
    end
  end
  rects
end

width = 640
height = 480

delay = ARGV.size > 1 ? ARGV[1].to_i : 1

SDL.init(SDL::Init::VIDEO)
window = SDL::Window.new("TV", width, height, flags: SDL::Window::Flags.flags(SHOWN, RESIZABLE))
renderer = SDL::Renderer.new(window, SDL::Renderer::Flags::ACCELERATED | SDL::Renderer::Flags::PRESENTVSYNC)
texture = SDL::Texture.new(renderer, SDL::PIXELFORMAT_8888, LibSDL::TextureAccess::STREAMING.value, width, height)
pixels = Pointer(UInt32).malloc(width * height)
pitch = width * 4

frames = 0_u32
start = SDL.ticks

color_maker = ColorMaker.new(delay)
rects = parse_rectangles
puts "Rects: #{rects.size}"

while true
  SDL::Event.poll do |event|
    case event
    when SDL::Event::Quit, SDL::Event::Keyboard
      ms = SDL.ticks - start
      puts "#{frames} frames in #{ms} ms"
      puts "Average FPS: #{frames / (ms * 0.001)}"
      exit
    end
  end

  texture.lock(nil, pointerof(pixels).as(Void**), pointerof(pitch))

  (height // 10).times do |h|
    (width // 10).times do |w|
      rect = rects.find { |rect| rect.contains?(w, h) }
      10.times do |y|
        10.times do |x|
          pixels[(y + 10 * h) * width + (x + 10 * w)] = (rect ? (rect.light? ? color_maker.light_color : color_maker.dark_color) : color_maker.black_color).to_u32!
        end
      end
    end
  end

  color_maker.next

  texture.unlock

  renderer.clear
  renderer.copy(texture)
  renderer.present

  frames += 1
end
