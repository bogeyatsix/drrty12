#! /usr/bin/env ruby

require 'set'
require 'pp'
require 'beckett/arrayx'
require 'beckett/stray'
require 'beckett/ext1'
require 'beckett/marshalize'

class World

  attr_reader :map, :animals, :plants, :mates, :turncount, :gen
  attr_writer :plants, :animals, :mates, :gen
  
  def initialize(init_pop)
    @map = Array.new(2) { DIMENSION }.to_matrix { ' ' }
    @genzero_pop = init_pop
    @pid = 0
    @start = Time.now
    @gen = 1
    
    @plants = {}
    @animals = []
    @mates = []
    @turncount = 1
  end

  def populate_map
    @map.each { |row| row.fill(' ') }
    @plants.each { |pl,pos| @map.mx_assign( pos.first, pos.last, pl.marker ) }
    @animals.each { |anim| @map.mx_assign( anim.pos.first, anim.pos.last, anim.marker ) }
  end

  def render_map
    print `clear`
    @map.each { |row| puts row.join('  ') }
  end

  def render_stats

    puts "\nStarted: #{@start.asctime.gsub(/^\w{3,4} /,'')} | Init. pop: #{@genzero_pop} "
    puts "\nPopulation: #{@animals.size} | #{@animals.size <= 100 ? '|'*@animals.size : "\e[35m|\e[0m"*(@animals.size/10)  }"
    puts "Average lifespan: #{@animals.inject([]) { |a,x| a << x.lifespan }.mean.round}"
    puts "Vegetation: #{@plants.size}"
    puts "\nGeneration: #{@gen} | Turn: #{@turncount} | Elapsed: #{((Time.now-@start)/60).roundf(1)} mins."
    puts "\n"
    pp " ID | L | R | F | B | FR| FL| BR| BL| M | S | T  | M | TOL |"

    @animals.last(5).each { |anim| anim.print_chromosome }
    
  end

  def turn
    @animals.shuffle!
    @animals.each { |anim| anim.turn }
    @animals.each { |anim| anim.find_mate }
    breed if (@mates.size%2).zero? && @mates.size != 0
    expire_old
    @turncount+=1
  end

  def generate_eco

    x = Set.new
    n = (200..MAX_ECO).pick
    n = MAX_ECO if @gen == 1
    i = 0

    until x.size == n || i == MAX_ECO*2
      a = rand_pos
      x.add(a) unless animal_positions.has_value?(a)
      i += 1
    end

    x.each { |pos| @plants[Plant.new(pos)] = pos }

  end

  def animal_positions
    @animals.inject({}) { |h,x| h.update x => x.pos }
  end

  def get_id
    @pid+=1
    @pid
  end

  def genesis
    x = Set.new
    until x.size == @genzero_pop
      x << rand_pos
    end
    positions = x.to_a
    @genzero_pop.times { pos = positions.shift ; @animals << Moneron.new(pos) }
  end

  private

  def breed
    
    @mates.each do |parents|

      child = Moneron.new(parents[0].pos)
      child.pos = rand_pos(1)

      child.mobility = rand(3) + (parents[rand(2)]).mobility if inherit?
      child.lifespan = (parents[rand(2)]).lifespan
      child.memory = (parents[rand(2)]).memory if inherit?
      child.hunger_tolerance = (parents[rand(2)]).hunger_tolerance if inherit?
      child.fertility = (parents[rand(2)]).fertility if inherit?

      child.sight = rand(3) + (parents[rand(2)]).sight if inherit?
      child.leftsight = (parents[rand(2)]).leftsight if inherit?
      child.rightsight = (parents[rand(2)]).rightsight if inherit?
      child.frontsight = (parents[rand(2)]).frontsight if inherit?
      child.hindsight = (parents[rand(2)]).hindsight if inherit?

      child.front_peripheral_r = (parents[rand(2)]).front_peripheral_r if inherit?
      child.front_peripheral_l = (parents[rand(2)]).front_peripheral_l if inherit?
      child.back_peripheral_r = (parents[rand(2)]).back_peripheral_r if inherit?
      child.back_peripheral_l = (parents[rand(2)]).back_peripheral_l if inherit?

      @animals << child
      
    end

    @mates.clear

  end

  def expire_old
    @animals.delete_if { |anim| anim.lifespan <= 0 }
  end

  def inherit?
    rand(1000) <= 600 ? true : false
  end

  def rand_pos(x=0)
    Array.new(2) { rand( DIMENSION-x ) }
  end

end

class Weather

  def initialize
  end

  def climate
    y = (rand*10).to_i
  end

end

class Life

  attr_reader :pid, :mobility, :lifespan, :pos, :memory, :hunger_tolerance, :sight, 
              :fertility, :vision, :leftsight, :rightsight, :frontsight, :hindsight,
              :front_peripheral_r, :front_peripheral_l, :back_peripheral_r, :back_peripheral_l

  attr_writer :pid, :mobility, :lifespan, :pos, :memory, :hunger_tolerance, :sight,
              :fertility, :vision, :leftsight, :rightsight, :frontsight, :hindsight,
              :front_peripheral_r, :front_peripheral_l, :back_peripheral_r, :back_peripheral_l
  
  def initialize(pos)

    # Creature Constants

    @pid = $WORLD.get_id
    @mobility = (1..4).pick
    @lifespan = (1..20).pick
    @memory = (4..20).pick
    @hunger_tolerance = rand.roundf(2)
    @fertility = (rand*10).round

    # Creature Variables
    
    @history = []
    @pos = pos
    @vision = 0             # Set from Life#survey

    # Sight

    @sight = (1..5).pick
    @leftsight = rand(2)
    @rightsight = rand(2)
    @frontsight = rand(2)
    @hindsight = rand(2)
    @front_peripheral_r = rand(2)
    @front_peripheral_l = rand(2)
    @back_peripheral_r = rand(2)
    @back_peripheral_l = rand(2)

  end

  def turn

    food_targets = hunt

    p1 = @pos.dup
    
    unless food_targets.empty?
      meal = food_targets.keys.pick
      @pos = food_targets[meal]
      remember(1)
      feed(meal)
    else
      remember(0)
      @pos = roam
    end

    x = @pos[0]-p1[0]
    y = @pos[1]-p1[1]
    d = Math.sqrt( x**2 + y**2 )

    if d <= 1.1
      @lifespan-=1
    elsif d <= 5.0
      @lifespan-=2
    else
      @lifespan-=3
    end
  
  end

  def deprecated_eaten?
    eat = (@history.last(@memory).sum).to_f
    mem = @memory.to_f
    return (eat/mem).roundf(2)
  end

  def eaten?
    eat = (@history.last(10).sum).to_f
    return (eat/10).roundf(2)
  end

  def print_chromosome
    x = [ @pid,@leftsight, 
          @rightsight, 
          @frontsight, 
          @hindsight, 
          @front_peripheral_r, 
          @front_peripheral_l,
          @back_peripheral_r, 
          @back_peripheral_l,
          @mobility, 
          @sight, 
          @vision, 
          @memory, 
          @hunger_tolerance,
          @fertility]
    pp x.join(' | ')
  end

  private

  def wrap(x)
    if x > DIMENSION-1
       return x - DIMENSION + 1
    elsif x < 0
       return x + DIMENSION
    else
       return x
    end
  end

  def wrapv(x)
    if x > DIMENSION-1
       return DIMENSION-1
    elsif x < 0
       return 0
    else
       return x
    end
  end

  def survey
    x,y = @pos.first , @pos.last
    surrounding = []
    (1..@sight).each do |i|
      surrounding << [wrapv(x+i),y] if @frontsight == 1
      surrounding << [wrapv(x-i),y] if @hindsight == 1
      surrounding << [x,wrapv(y+i)] if @rightsight == 1
      surrounding << [x,wrapv(y-i)] if @leftsight == 1
      surrounding << [wrapv(x+i),wrapv(y+i)] if @front_peripheral_r == 1
      surrounding << [wrapv(x+i),wrapv(y-i)] if @front_peripheral_l == 1
      surrounding << [wrapv(x-i),wrapv(y+i)] if @back_peripheral_r == 1
      surrounding << [wrapv(x-i),wrapv(y-i)] if @back_peripheral_l == 1
    end
    @vision = surrounding.size
    return surrounding
  end

  def mate_survey
    x,y = @pos.first , @pos.last
    i = 1
    surrounding = []
      surrounding << [wrapv(x+i),y]
      surrounding << [wrapv(x-i),y]
      surrounding << [x,wrapv(y+i)]
      surrounding << [x,wrapv(y-i)]
      surrounding << [wrapv(x+i),wrapv(y+i)] if DIMENSION >= 50
      surrounding << [wrapv(x+i),wrapv(y-i)] if DIMENSION >= 50
      surrounding << [wrapv(x-i),wrapv(y+i)] if DIMENSION >= 50
      surrounding << [wrapv(x-i),wrapv(y-i)] if DIMENSION >= 50
    return surrounding
  end

  def remember(x)
    @history.slice!(0..100) if @history.size >= 101
    @history << x
  end

end

class Plant < Life

  attr_reader :marker, :species, :energy

  def initialize(pos)
    @lifespan = 500
    @pos = pos
    @species = speciate
    @marker = get_marker
    @energy = get_energy
    reposition
  end

  private

  def speciate
    x = rand.roundf(2)
    y = nil
    x <= 0.7 ? y = 0 : nil
    x > 0.7 && x < 0.95 ? y = 1 : nil
    x >= 0.95 ? y = 2 : nil
    y
  end

  def get_energy
    case @species
      when 0 : 10
      when 1 : 15
      when 2 : 25
    end
  end

  def get_marker
    case @species
      when 0 : "\e[34m#{:*}\e[0m"
      when 1 : "\e[35m#{:*}\e[0m"
      when 2 : "\e[36m#{:*}\e[0m"
    end
  end

  def reposition
    case @species
      when 0 : @pos.collect! { |x| wrapv(x*(1..2).pick) }
      when 1 : @pos.collect! { |x| wrapv(x/(1..4).pick) }
      when 2 : @pos = @pos
    end
  end

  def wrapv(x)
    if x > DIMENSION-1
       return DIMENSION-1
    elsif x < 0
       return 0
    else
       return x
    end
  end

end

class Moneron < Life

  def feed(meal)
    @lifespan += meal.energy
    $WORLD.plants.delete(meal)
  end

  def marker
    if @lifespan <= 100
      return "\e[31m#{@vision}\e[0m"
    elsif @lifespan <= 300
      return "\e[35m#{@vision}\e[0m"
    elsif @lifespan <= 400
      return "\e[33m#{@vision}\e[0m"
    elsif @lifespan <= 600
      return "\e[32m#{@vision}\e[0m"
    else
      return "\e[36m#{@vision}\e[0m"
    end
  end

  def hunt
    targets = {}
    survey.each do |pos|
      meal = $WORLD.plants.find { |k,v| v == pos }
      unless meal.nil?
        targets[meal.first] = pos if edible?(meal.first)
      end
    end
    return targets
  end

  def roam
    x,y = @pos.first,@pos.last
    q,r,s,t = rand(@mobility) , rand(@mobility) , rand(@mobility) , rand(@mobility)
    new_pos = []
    new_pos << wrap( [x-q,x+r].pick )
    new_pos << wrap( [y-s,y+t].pick )
    return new_pos
  end

  def find_mate
    mate_survey.each do |pos|
      mate = $WORLD.animal_positions.find { |k,v| v == pos }
      if mate != nil && fuck?
          x = [] << self << mate.first
          $WORLD.mates << x unless $WORLD.mates.include?(self)
      end
    end
  end

  def fuck?
    i = 0
    i+=1 if eaten? > @hunger_tolerance
    i+=1 if (rand*10).round <= @fertility
    i == 2 ? true : false
  end

  def edible?(meal)
    if @vision < 65 && meal.species == 0
      return true
    elsif @vision >= 65 && @vision < 100 && meal.species == 1
      return true
    elsif @vision >= 100 && meal.species == 2
      return true
    end
  end

end

#-- Main --#

DIMENSION = 40
MAX_ECO = 200
INIT_POP = 10
TURNS_PER_GEN = 150
SHOW_MAP = true

if ARGV.empty?
  $WORLD = World.new(INIT_POP)
  $WORLD.genesis
  $WORLD.generate_eco
  marshal('darwins_children',$WORLD)
else
  $WORLD = marshal('darwins_children')
end

loop do

  if ($WORLD.turn % TURNS_PER_GEN).zero?
     $WORLD.gen += 1
     $WORLD.generate_eco
  end

  if $WORLD.animals.size < 200 && SHOW_MAP
     $WORLD.populate_map
     $WORLD.render_map
     $WORLD.render_stats
     sleep 0.2
   else
     $WORLD.render_stats
     $WORLD.turn
   end

   break if $WORLD.animals.size <= 1

   marshal('darwins_children',$WORLD) if ($WORLD.turn % 10).zero?

end