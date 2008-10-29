#! /usr/bin/env ruby

require 'pp'
require 'matrix'
require 'beckett/marshalize'

class Game

  attr_reader :players, :result, :playbook
  attr_writer :players

  def initialize
    @players = []
    @result = nil
    @board = Board.new
    @playbook = []
  end

  def render
    marshal('bpositions',@board.positions)
    positions = marshal('bpositions')
    positions.each { |row| row.collect! do |sym| 
      if sym =~ /o/
        sym.replace "\e[32mo\e[0m"
      elsif sym =~ /x/
        sym.replace "\e[31mx\e[0m"
      else
        sym = ' '
      end
    end 
    }
    positions.each { |row| puts row.join(" | ") }
  end

  def move(player,pos)
    @board.move(player,pos)
  end

  def won?
    k = []
    m = Matrix[*@board.positions]
    (0..2).each do |i|
      k.push m.row(i).to_a.join
      k.push m.column(i).to_a.join    
    end
      i = -1
    k.push @board.positions.inject("") { |t,x| i+=1 ; t << x[i] }
      i += 1
    k.push @board.positions.inject("") { |t,x| i-=1 ; t << x[i] }
    k.include?("xxx") or k.include?("ooo") ? true : false
  end
  
  def tie?
    @board.positions_left == [] ? true : false
  end

  def play

  loop do

    @players.each do |player|
    puts "Player #{player.id} turn."

    begin

    pos = player.getmove(@board)
    move(player.id,pos)
    @playbook.push(pos)
    render

      if won?
        @result = player.id
        break
      elsif tie?
        @result = 0
        break
      end

    rescue => e ; puts "Invalid move. Try again." ; retry end

    end

    break if result != nil

  end

  end

  def reset
    @result = nil
    @board = Board.new
    @playbook = []
  end

end

class Board

  attr_reader :positions

  def initialize
    @positions = Array.new(3) { Array.new(3,' ') }
    @coded_positions = Hash.new
  end

  def move(player,pos)
    sign = case player ; when 1 : 'x' ; when 2 : 'o' end
    pos =~ /^./
    row = case $&
          when 'a' : @positions[0]
          when 'b' : @positions[1]
          when 'c' : @positions[2]
          end
    if row[$'.to_i] == ' ' and $'.to_i <= 3
       row[$'.to_i] = sign
    else
       raise "Invalid Move"
    end
  end

  def positions_left
    reflect
    remaining = @coded_positions.dup.delete_if { |k,v| v != ' ' }
    return remaining.keys
  end

  private

  def reflect
    h = Hash.new
    h['a0'] = @positions[0][0]
    h['a1'] = @positions[0][1]
    h['a2'] = @positions[0][2]
    h['b0'] = @positions[1][0]
    h['b1'] = @positions[1][1]
    h['b2'] = @positions[1][2]
    h['c0'] = @positions[2][0]
    h['c1'] = @positions[2][1]
    h['c2'] = @positions[2][2]
    @coded_positions = h
  end

end

class Player

  attr_reader :id

  def initialize(id)
    @id = id
  end

end

class HumanPlayer < Player

  def getmove(current_board)
    pos = $stdin.gets.chomp.to_i
      case pos
        when 7 : return 'a0'
        when 8 : return 'a1'
        when 9 : return 'a2'
        when 4 : return 'b0'
        when 5 : return 'b1'
        when 6 : return 'b2'
        when 1 : return 'c0'
        when 2 : return 'c1'
        when 3 : return 'c2'
        end
  end

end

class DumbPlayer < Player
    
  def getmove(current_board)
    x = current_board.positions_left.size
    h[rand(x)]
  end

end

class Hustler < Player

  def getmove(current_board)
    
    marshal('board_pos',current_board.positions)
    @positions_left = current_board.positions_left
    live,die = [],[]

    @positions_left.each do |code|
      testboard1 = assign(code,'o')
      testboard2 = assign(code,'x')
      die.push(code) if checkwin(testboard1) == 1
      live.push(code) if checkwin(testboard2) == -1
    end

    if live != [] : return live.first
    elsif die != [] : return die.last
    else
      return @positions_left[ rand( @positions_left.size ) ]
    end

  end

  private

  def checkwin(newboard)
      k = []
      m = Matrix[*newboard]
      (0..2).each do |i|
        k.push m.row(i).to_a.join
        k.push m.column(i).to_a.join
      end
        i = -1
      k.push newboard.inject("") { |t,x| i+=1 ; t << x[i] }
        i += 1
      k.push newboard.inject("") { |t,x| i-=1 ; t << x[i] }
      if k.include?("xxx") then return -1
      elsif k.include?("ooo") then return 1
      else return 0
      end
  end

  def assign(code,sign)
    testboard = marshal('board_pos')
    case code
      when 'a0' : testboard[0][0] = sign
      when 'a1' : testboard[0][1] = sign
      when 'a2' : testboard[0][2] = sign
      when 'b0' : testboard[1][0] = sign
      when 'b1' : testboard[1][1] = sign
      when 'b2' : testboard[1][2] = sign
      when 'c0' : testboard[2][0] = sign
      when 'c1' : testboard[2][1] = sign
      when 'c2' : testboard[2][2] = sign
      end
      testboard
  end

end

## Main ##

game = Game.new

unless ARGV.empty?
  
    ARGV.each_with_index do |player,i| i+=1
    game.players << case player
      when 'human'  : HumanPlayer.new(i)
      when 'dumb'   : DumbPlayer.new(i)
      when 'hustle' : Hustler.new(i)
    end
  end

else

  game.players << HumanPlayer.new(1) << Hustler.new(2)

end

loop do

puts "\nNEW GAME"

game.render

game.play

if game.result == 0
  puts "*"*15 + "\n" + "Game is tied."
else
  puts "*"*15 + "\n" + "Player #{game.result} has won."
end

pp game.playbook

game.reset

sleep 2

end