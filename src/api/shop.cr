class Shop
  def self.setPathApi(url : String)
    post "#{url}/shop" do |env|
      begin
        if env.params.json.has_key?("shop_name") && env.params.json.has_key?("address")
          user_id = Authentication.current_session(env.request.headers["token"])
          shop_name = env.params.json["shop_name"]
          address = env.params.json["address"]
          phone = validateField("phone", env)
          phone2 = validateField("phone2", env)
          description = validateField("description", env)
          cover_image = validateField("cover_image", env)
          logo = validateField("logo", env)
          accept_card = validateField("accept_card", env)
          list_cards = validateField("list_cards", env)
          type_s = validateField("type_s", env)
          service_type = validateField("service_type", env)
          lat = validateField("lat", env)
          lon = validateField("lon", env)

          shop = [] of DB::Any

          shop << shop_name.to_s
          shop << address.to_s
          shop << phone
          shop << phone2
          shop << description
          shop << cover_image
          shop << accept_card
          shop << list_cards
          shop << type_s
          shop << lat
          shop << lon
          shop << false
          shop << user_id
          shop << logo

          shop_id_insert = DB_K
            .table(:shop)
            .insert([:shop_name, :address, :phone, :phone2, :description, :cover_image, :accept_card, :list_cards, :type_s, :lat, :lon, :score_shop, :user_id, :logo], shop)
            .execute

          MONGO.insert("shop", {
            "name"     => shop_name.to_s,
            "shop_id"  => shop_id_insert.to_s,
            "location" => {
              "type"        => "Point",
              "coordinates" => ["#{env.params.json["lon"]}".to_f, "#{env.params.json["lat"]}".to_f],
            },
            "category" => type_s.to_s,
            "status"   => false,
          })

          if env.params.json.has_key?("list_images")
            list_images_array = Array(String).from_json("#{env.params.json["list_images"]}")

            list_images_array.each { |url|
              DB_K
                .table(:images_shop)
                .insert([:url_image, :shop_id], [url, shop_id_insert.to_s])
                .execute
            }
          end

          if env.params.json.has_key?("service_type")
            DB_K
              .table(:type_service)
              .insert([:service, :shop_id], [service_type, shop_id_insert.to_s])
              .execute
          end

          env.response.status_code = 200
          {message: "Create shop success", status: 200}.to_json
        else
          raise Exception.new("Name of shop or address can't empty")
        end
      rescue exception
        error = "#{exception}"
        case error
        when "Name of shop or address can't empty"
          env.response.status_code = 400
          {message: error}.to_json
        else
          puts error
          env.response.status_code = 500
        end
      end
    end

    get "#{url}/shop/:shop_id" do |env|
      shop_id = env.params.url["shop_id"]
      user_id = Authentication.current_session(env.request.headers["token"])

      shop_result = DB_K
        .select([
        :shop_id,
        :shop_name,
        :address,
        :phone,
        :phone2,
        :description,
        :cover_image,
        :accept_card,
        :list_cards,
        :type_s,
        :lat,
        :lon,
        :score_shop,
        :status,
      ])
        .table(:shop)
        .join(:LEFT, :images_shop, [:url_image], [:shop_id, :shop_id])
        .join(:LEFT, :shop_schedules, [:LUN, :MAR, :MIE, :JUE, :VIE, :SAB, :DOM], [:shop_id, :shop_id])
        .join(:LEFT, :usersk, [:user_id], [:user_id, :user_id])
        .where(:shop_id, shop_id)
        .and(:user_id, user_id)
        .group_concat([:url_image, :images_shop, :url], :image_id, :images)
        .first

      shop_result
    end

    put "#{url}/shop/:shop_id/update" do |env|
      user_id = Authentication.current_session(env.request.headers["token"])
      shop_id = env.params.url["shop_id"]
      shop_name = env.params.json.has_key?("shop_name") ? env.params.json["shop_name"] : nil
      address = env.params.json.has_key?("address") ? env.params.json["address"] : nil
      phone = env.params.json.has_key?("phone") ? env.params.json["phone"] : nil
      phone2 = env.params.json.has_key?("phone2") ? env.params.json["phone2"] : nil
      description = env.params.json.has_key?("description") ? env.params.json["description"] : nil
      cover_image = env.params.json.has_key?("cover_image") ? env.params.json["cover_image"] : nil
      logo = env.params.json.has_key?("logo") ? env.params.json["logo"] : nil
      accept_card = env.params.json.has_key?("accept_card") ? env.params.json["accept_card"] : nil
      list_cards = env.params.json.has_key?("list_cards") ? env.params.json["list_cards"] : nil
      type_s = env.params.json.has_key?("type_s") ? env.params.json["type_s"] : nil
      service_type = env.params.json.has_key?("service_type") ? env.params.json["service_type"] : nil
      lat = env.params.json.has_key?("lat") ? env.params.json["lat"] : nil
      lon = env.params.json.has_key?("lon") ? env.params.json["lon"] : nil

      field_shop_update = [] of String
      data_shop_update = [] of String | Int32 | Float64
      mongo_update = {} of String => Hash(String, String | Array(Float64)) | String

      begin
        if shop_name
          field_shop_update << "shop_name"
          data_shop_update << shop_name.to_s
          mongo_update["name"] = shop_name.to_s
        end

        if address
          field_shop_update << "address"
          data_shop_update << address.to_s
        end

        if phone
          field_shop_update << "phone"
          data_shop_update << "#{phone}".to_i
        end

        if phone2
          field_shop_update << "phone2"
          data_shop_update << "#{phone2}".to_i
        end

        if description
          field_shop_update << "description"
          data_shop_update << description.to_s
        end

        if cover_image
          field_shop_update << "cover_image"
          data_shop_update << cover_image.to_s
        end

        if accept_card
          field_shop_update << "accept_card"
          data_shop_update << accept_card.to_s
        end

        if list_cards
          field_shop_update << "list_cards"
          data_shop_update << list_cards.to_s
        end

        if type_s
          field_shop_update << "type_s"
          data_shop_update << type_s.to_s
        end

        if lat && lon
          field_shop_update << "lat"
          data_shop_update << "#{lat}".to_f
          field_shop_update << "lon"
          data_shop_update << "#{lon}".to_f
          mongo_update["location"] = {
            "type"        => "Point",
            "coordinates" => ["#{lon}".to_f, "#{lat}".to_f],
          }
        end

        if logo
          field_shop_update << "logo"
          data_shop_update << "#{logo}".to_s
        end

        DB_K
          .table(:shop)
          .update(field_shop_update, data_shop_update)
          .where(:user_id, user_id)
          .and(:shop_id, shop_id)
          .execute

        MONGO.update("shop", {"shop_id" => shop_id}, {"$set" => mongo_update})

        env.response.status_code = 200
        {message: "Success update", status_code: 200}.to_json
      rescue exception
        puts exception

        env.response.status_code = 400
        {message: "Error params request"}.to_json
      end
    end

    post "#{url}/shops/:shop_id/update/images" do |env|
      user_id = Authentication.current_session(env.request.headers["token"])
      shop_id = env.params.url["shop_id"]

      begin
        response_result = ""
        HTTP::FormData.parse(env.request) do |upload|
          result_cover = CLOUDINARY.upload(upload, "shop_images")
          response_result = JSON.parse(result_cover)
        end

        DB_K
          .table(:images_shop)
          .insert([:url_image, :shop_id], [response_result["url"].to_s, shop_id.to_s])
          .execute

        {image: response_result["url"], message: "success"}.to_json
      rescue exception
        puts exception
        env.response.status_code = 500
        {message: "Error al agregar nueva imagen"}.to_json
      end
    end

    delete "#{url}/shops/:shop_id/image" do |env|
      shop_id = env.params.url["shop_id"]
      url_image = env.params.json.has_key?("url_image") ? env.params.json["url_image"] : nil

      begin
        DB_K
          .delete
          .table(:images_shop)
          .where(:url_image, url_image.to_s)
          .and(:shop_id, shop_id)
          .execute

        {message: "Imagen eliminada"}.to_json
      rescue exception
        puts exception

        env.response.status_code = 500
        {message: "Error al eliminar la imagen"}.to_json
      end
    end

    get "#{url}/shops/:lat/:lon" do |env|
      limit = env.params.query["limit"].to_i
      skip = env.params.query["skip"].to_i
      maxDistance = env.params.query["maxDistance"].to_i
      begin
        get_shops = MONGO.aggregate([
          {
            "$geoNear" => {
              "near" => {
                "type"        => "Point",
                "coordinates" => ["#{env.params.url["lon"]}".to_f, "#{env.params.url["lat"]}".to_f],
              },
              "maxDistance"   => maxDistance,
              "spherical"     => true,
              "distanceField" => "distance",
            },
          },
          {
            "$match" => {
              "status" => true,
            },
          },
          {
            "$limit" => limit,
          },
          {
            "$skip" => skip,
          },
        ], "shop")

        result_properties = [] of JSON::Any
        values_arr = [] of Int32

        if get_shops.empty?
          env.response.status_code = 200
          next get_shops.to_json
        end

        get_shops.map { |value| values_arr << "#{value["shop_id"]}".to_i }

        shops = DB_K
          .select([
          :shop_id,
          :shop_name,
          :address,
          :phone,
          :score_shop,
          :cover_image,
          :type_s,
        ])
          .table(:shop)
          .where_in(:shop_id, values_arr)
          .execute_query

        shops.not_nil!.map { |shop_data|
          hash_match = get_shops.select! { |hash_r| "#{hash_r["shop_id"]}".to_i == shop_data["shop_id"] }
          shop_data["distance"] = hash_match.first["distance"]
        }

        shops.to_json
      rescue exception
        puts exception

        env.response.status_code = 400
        {message: "Error params request"}.to_json
      end
    end
  end

  def self.validateField(field, env)
    if field == "accept_card"
      if env.params.json.has_key?("#{field}")
        env.params.json["accept_card"] == true ? true : false
      end
    else
      env.params.json.has_key?("#{field}") ? (field == "phone" || field == "phone2" ? (env.params.json["#{field}"].to_s).to_i : env.params.json["#{field}"].to_s) : ""
    end
  end
end
