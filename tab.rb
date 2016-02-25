require 'httparty'
require 'watir-webdriver'

teams_map = {
  # tab: fte
  :Hornets => :CHA,
  :Cavaliers => :CLE,
  :Pacers => :IND,
  :Knicks => :NY,
  :Raptors => :TOR,
  :Timberwolves => :MIN,
  :Warriors => :GS,
  :Heat => :MIA,
  :Grizzlies => :MEM,
  :Lakers => :LAL,
  :Thunder => :OKC,
  :Mavericks => :DAL,
  :Pistons => :DET,
  :Bulls => :CHI,
  :Clippers => :LAC,
  :Spurs => :SA,
  :'76ers' => :PHI,
  :Wizards => :WSH,
  :Nuggets => :DEN,
  :Kings => :SAC,
  :Magic => :ORL,
  :Celtics => :BOS,
  :Suns => :PHX,
  :Blazers => :POR,
  :Rockets => :HOU,
  :Nets => :BKN,
  :Bucks => :MIL,
  :Pelicans => :NO,
  :Jazz => :UTA,
  :Hawks => :ATL,
}

games = []

tab_doc = HTTParty.get('http://www.tab.co.nz/sport/ajax/page/comp/nba').parsed_response

tab_options = tab_doc.scan(/<a href="\/sport\/#\d+">(.*?)<\/a>/)
tab_options.each do |tab_option|
  tab_option = tab_option[0]
  next unless tab_option =~ /Head to Head/

  teams = {}
  teams_map.each do |tab, fte|
    pos = tab_option =~ /#{tab}/
    teams[fte] = pos if pos
  end
  teams = Hash[teams.to_a.sort_by { |t| t[1] }]
  if teams.length != 2
    puts "Wrong team count: #{tab_option}"
  end
  teams = teams.keys

  prices = []
  tab_option.scan(/\$[\d\.]+/).each do |match|
    prices << match.sub('$', '').to_f
  end

  games << {
    teams: teams,
    prices: prices,
    fte: [],
  }
end

browser = Watir::Browser.start('http://projects.fivethirtyeight.com/2016-nba-picks/')
away_teams = browser.tr(class: 'away').text.split("\n")
away_probs = browser.tr(class: 'prob-row-top').text.split("\n")[1].split(' ')
home_probs = browser.tr(class: 'prob-row-bottom').text.split("\n")[0].split(' ')
home_teams = browser.tr(class: 'home').text.split("\n")

browser.div(id: 'arrow-right').click

away_teams += browser.tr(class: 'away').text.split("\n")
away_probs += browser.tr(class: 'prob-row-top').text.split("\n")[1].split(' ')
home_probs += browser.tr(class: 'prob-row-bottom').text.split("\n")[0].split(' ')
home_teams += browser.tr(class: 'home').text.split("\n")

away_teams.delete_if { |i| i.length != 2 && i.length != 3 }
away_probs = away_probs.map { |i| i.to_i }.delete_if { |i| i == 0 }
home_probs = home_probs.map { |i| i.to_i }.delete_if { |i| i == 0 }
home_teams.delete_if { |i| i.length != 2 && i.length != 3 }

browser.close

games.each do |game|
  away_teams.each_with_index do |away_team, idx|
    home_team = home_teams[idx]
    away_prob = away_probs[idx]
    home_prob = home_probs[idx]
    next unless game[:teams].include?(away_team.to_sym) && game[:teams].include?(home_team.to_sym)
    game[:teams].each_with_index do |team, idx2|
      game[:fte][idx2] = if away_team == team.to_s
        away_prob
      else
        home_prob
      end
    end
  end
end

games.each do |game|
  puts "#{game[:teams][0]}-#{game[:teams][1]}"
  game[:teams].each_with_index do |team, idx|
    tab_return = game[:prices][idx] - 1
    expected_return = tab_return * (game[:fte][idx].to_f / 100)
    puts "        #{game[:teams][idx]} to win: #{game[:fte][idx]}% - $#{expected_return.round(2)}"
  end
  puts ''
end
