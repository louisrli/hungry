# hungry.coffee
# 
# Author: Louis Li

# Download the API data from the client. Less speedy than caching on a server,
# but since we can assume most people are on Harvard internet and have enough
# bandwidth to download another 1KB of data, it shouldn't have a huge impact :)
Date::getDayName = ->
  ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'][this.getDay()]

Date::formatDate = ->
  dd = this.getDate()
  mm = this.getMonth() + 1
  yyyy = this.getFullYear()
  
  dd = '0' + dd if dd < 10
  mm = '0' + mm if mm < 10
  return "#{yyyy}-#{mm}-#{dd}"

extractDateInfo = (date, name) ->
  date: date.formatDate()
  day: date.getDayName()
  type: name

today = extractDateInfo(new Date(), "today")

MS_PER_DAY = 24 * 60 * 60 * 1000
tomorrow = extractDateInfo(new Date(new Date().getTime() + MS_PER_DAY), "tomorrow")

API_KEY = "a1ba99910ddd9ed75bc9a48a440b1906"
getEndpoint = (date, meal) ->
  "http://api.cs50.net/food/3/menus?key=#{API_KEY}&meal=#{meal}&sdt=#{date}&output=jsonp&callback=?"

debug = false
if debug
  today =
    date: "2013-05-02"
    day: "wednesday"
    type: "today"

  tomorrow =
    date: "2013-05-03"
    day: "thursday"
    type: "tomorrow"

createMeal = (dateInfo, meal) ->
  o = _.extend({ meal: meal }, dateInfo)
  o.url = getEndpoint(dateInfo.date, meal)
  return o

# Annoyingly, the food API has meal set to "brunch" for sundays
# In the 2014-2015 school year, for Saturday, the "meal" attribute is LUNCH, but the "category" is BRUNCH
brunchOrLunch = (day) ->
  if day.toLowerCase() is "sunday" then "brunch" else "lunch"

MEALS = [
  createMeal(today, brunchOrLunch today.day)
  createMeal(today, "dinner")
  createMeal(tomorrow, brunchOrLunch tomorrow.day)
]

# The API always returns a ton of extraneous stuff for brunch.
# Let's blacklist the things that appear every brunch in the true
# spirit of Hungry.
BRUNCH_BLACKLIST = [
  "Grapefruit", "Cage-Free Egg Whites", "Shredded Hashbrowns",
  "Zucchini Walnut Bread", "Stir Fry Vegetables", "Harvard Fruit Salad",
  "Assorted Bagels", "Whole Wheat Blueberry Muffin", "Smoked Salmon Platter",
  "Carrot, Walnut Cake with Cream Cheese Icing", "Scrambled Cage Free Eggs",
  "Turkey Bacon", "Hard Cooked Eggs - Cage Free", "Cage Free Eggs Cooked to Order",
  "Triple Berry Tea Bread", "Whole Wheat Banana Nut Muffin"
]

#
# Models
#
class Entree extends Backbone.Model

class EntreeList extends Backbone.Model

class Menu extends Backbone.Collection
  model: EntreeList
  
  createEntreeList: (obj) ->
    o = _.extend({}, obj)  # clone for safety
    o.entrees = _.map(o.entrees, (e) -> new Entree(e))
    model = new EntreeList(o)


  fetch: (options) ->
    collection = @
    promises = _.map(MEALS, (o) -> $.getJSON(o.url))
    # Things get ugly here in order to run the AJAX
    # calls in parallel
    return $.when.apply($, promises).then(
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
              .filter((i) -> 
                # Take entree items, ignore entree salads and extraneous brunch items
                (i.category.indexOf("ENTREE") != -1 and not (i.category is "ENTREE SALADS")) or
                  (i.category is "BRUNCH" and not (i.name in BRUNCH_BLACKLIST)) or
                  (i.category is "TODAY\\'S SOUP")
              )
              .value()

          mealObject
        )

        # Augment with our original metadata
        for i in [0..(meals.length - 1)]
          meals[i] = _.extend(meals[i], MEALS[i])

        collection.reset(
          _.map(meals, (entreeList) -> collection.createEntreeList(entreeList))
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
  className: "empty-message"
  template: "#empty-menu"

class MenuView extends Marionette.CollectionView
  itemView: EntreeListCompositeView
  itemViewContainer: "div"
  emptyView: EmptyMenuView

class FooterView extends Marionette.ItemView
  template: "#footer"
  className: "footer"

  onRender: ->
    FADE_OPACITY = 0.4
    @$el.fadeTo(300, FADE_OPACITY)

    @$el.hover(
      (-> $(this).fadeTo(300, 1.0)),
      (-> $(this).fadeTo(300, FADE_OPACITY))
    )


#
# Application
#
App = new Marionette.Application()
App.addRegions(
  mainRegion: "#food-menu"
  footerRegion: "#footer-region"
)

regionFadein = (view) ->
  @$el.hide()
  @$el.html(view.el)
  @$el.fadeIn(800)

App.mainRegion.open = regionFadein
App.footerRegion.open = regionFadein

App.addInitializer((options) ->
  hungryMenu = new Menu()
  hungryMenu.fetch().then(->
    menuView = new MenuView(
      collection: hungryMenu
    )

    if hungryMenu.every((meal) -> meal.get("entrees").length is 0)
      App.mainRegion.show(new EmptyMenuView())
    else
      App.mainRegion.show(menuView)
  )

  App.footerRegion.show(new FooterView())
)

App.start()
