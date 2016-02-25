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
  }
end

browser = Watir::Browser.start('http://projects.fivethirtyeight.com/2016-nba-picks/')
away_teams = browser.tr(class: 'away').text.split("\n")
away_probs = browser.tr(class: 'prob-row-top').text.split("\n")
home_probs = browser.tr(class: 'prob-row-bottom').text.split("\n")
home_teams = browser.tr(class: 'home').text.split("\n")
browser.close

[away_teams, home_teams, away_probs].each { |i| i.shift }

away_probs = away_probs[0].split(' ').map { |i| i.to_i }
home_probs = home_probs[0].split(' ').map { |i| i.to_i }

games.each do |game|
  away_position = nil
  home_position = nil
  game[:teams].each do |team|
    idx = away_teams.find_index(team.to_s)
    away_position = idx if idx
    idx = home_teams.find_index(team.to_s)
    home_position = idx if idx
  end
  if away_position == home_position
    away_prob = away_probs[away_position]
    home_prob = home_probs[away_position]
    if away_prob > home_prob
      game[:win] = away_teams[away_position].to_sym
      game[:fte] = away_prob
    else
      game[:win] = home_teams[away_position].to_sym
      game[:fte] = home_prob
    end
  end
end

games.each do |game|
  next if game[:fte] < 85
  tab_return = game[:prices][0] - 1
  expected_return = tab_return * (game[:fte].to_f / 100)
  next if expected_return < 0.2
  puts "#{game[:teams][0]}-#{game[:teams][1]} - #{game[:win]} - #{expected_return}"
end
