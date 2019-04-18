# schema.rb-to-ecto-schemas
Ruby on Rails schema.rb to Elixir's Ecto schemas

```
./to_ecto.rb -i ~/my/db/schema.rb -o ~/my/ecto/models/ -n MyApp

./to_ecto.rb -i ~/Documents/_panda/controle.git/db/schema.rb -o models -n EctoPanda --prefixes pubg,lol,csgo,dota2,ow --not-prefixes league,match,player,serie,team,tournament --inserted_at created_at
```
