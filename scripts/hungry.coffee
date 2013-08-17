# hungry.coffee
# 
# Author: Louis Li

# Download the API data from the client
# Less speedy than caching on a server,
# but since we can assume most people are on Harvard internet
# and have enough bandwidth to download another 1KB of data,
# it shouldn't have a huge impact :)
formatDate = (dateObject) ->
  dd = dateObject.getDate()
  mm = dateObject.getMonth() + 1
  yyyy = dateObject.getFullYear()
  
  dd = '0' + dd if dd < 10
  mm = '0' + mm if mm < 10
  return "#{yyyy}-#{mm}-#{dd}"

today = formatDate(new Date())

MS_PER_DAY = 24 * 60 * 60 * 1000
tomorrow = formatDate(new Date(new Date().getTime() + MS_PER_DAY))

# Make the API calls
getEndpoint = (date, meal) ->
  "http://food.cs50.net/api/1.3/menus?meal=#{meal}&sdt=#{date}&output=jsonp&callback=?"

today = "2013-05-02"
tomorrow = "2013-05-03"  # TODO debug

MEALS = [
  { date: today, meal: "lunch" },
  { date: today, meal: "dinner" },
  { date: tomorrow, meal: "lunch" }
]

_.each(MEALS, (o) ->
  o.url = getEndpoint(o.date, o.meal)
  if o.date is today then o.type = "today"
  if o.date is tomorrow then o.type = "tomorrow"

)

# Load the data from the API into the models
createEntreeList = (obj) ->
  o = _.extend({}, obj)  # clone for safety
  o.entrees = _.map(o.entrees, (e) -> new Entree(e)) 
  model = new EntreeList(o)

#
# Models
#
class Entree extends Backbone.Model

class EntreeList extends Backbone.Model

class Menu extends Backbone.Collection
  model: EntreeList

  fetch: (options) ->
    collection = @
    promises = _.map(MEALS, (o) -> $.getJSON(o.url))
    # Things get ugly here in order to run the AJAX
    # calls in parallel
    $.when.apply($, promises).then(
      ((data) ->
        # The only way to get each response from the AJAX
        # is to use `arguments`
        rawMeals = _.map(arguments, _.first)

        # Process the raw API data
        meals = _.map(rawMeals, (meal) ->
          mealObject = {}

          # Process each JSON response (meal-level)
          mealObject.entrees= _.chain(meal)
            .map((item) ->
              # Process each entree
              _.chain(item)
                .pick(['meal', 'date', 'name', 'category'])
                .value()
            )
              .filter((i) -> i.category in ["ENTREES"])
              .value()

          mealObject.meal = mealObject.entrees[0].meal  # TODO
          mealObject
        )

        # Augment with our original metadata
        for i in [0..(meals.length - 1)]
          meals[i] = _.extend(meals[i], MEALS[i])

        collection.reset(
          _.map(meals, (entreeList) -> createEntreeList(entreeList))
        )
      ),
      ((error) ->
        console.error error
      )
    )


#
# Views
#
class EntreeView extends Marionette.ItemView
  tagName: "li"
  template: "#entree-item"

class EntreeListCompositeView extends Marionette.CompositeView
  className: "meal-menu"
  template: "#meal-menu"
  itemView: EntreeView
  itemViewContainer: "ul"

  initialize: ->
    # Create a generic Backbone Collection, since Backbone
    # doesn't play well with nested collections
    @collection = new Backbone.Collection(@model.get("entrees"))

# Displayed when there's no menu items,
# i.e. CS50 Food API is down
class EmptyMenuView extends Marionette.ItemView
  tagName: "div"
  template: "#empty-menu"
  initialize: -> console.log "empty"

class MenuView extends Marionette.CollectionView
  itemView: EntreeListCompositeView
  itemViewContainer: "div"
  emptyView: EmptyMenuView
  initialize: ->
    console.log @model


#
# Application
#
App = new Marionette.Application()
App.addRegions(mainRegion: "#food-menu")

App.mainRegion.open = (view) ->
  @$el.hide()
  @$el.html(view.el)
  @$el.fadeIn(800)

App.addInitializer((options) ->
  HungryMenu = new Menu()
  HungryMenu.fetch()

  HungryMenu.on("reset", ->
    menuView = new MenuView(
      collection: @
    )
    App.mainRegion.show(menuView)
  )
)

App.start()
