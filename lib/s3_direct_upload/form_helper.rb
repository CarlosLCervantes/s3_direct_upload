module S3DirectUpload
  module UploadHelper
    def s3_uploader_form(options = {}, &block)
      uploader = S3Uploader.new(options)
      form_tag(uploader.url, uploader.form_options) do
        uploader.fields.map do |name, value|
          hidden_field_tag(name, value)
        end.join.html_safe + capture(&block)
      end
    end

    class S3Uploader
      def initialize(options)
        @options = options.reverse_merge(
          aws_access_key_id: S3DirectUpload.config.access_key_id,
          aws_secret_access_key: S3DirectUpload.config.secret_access_key,
          bucket: S3DirectUpload.config.bucket,
          region: S3DirectUpload.config.region || "s3",
          acl: "public-read",
          expiration: 10.hours.from_now.utc.iso8601,
          max_file_size: 500.megabytes,
          as: "file",
          key: key
        )
      end

      def form_options
        {
          id: @options[:id],
          class: @options[:class],
          method: "post",
          authenticity_token: false,
          multipart: true,
          data: {
            post: @options[:post],
            as: @options[:as]
          }.reverse_merge(@options[:data] || {})
        }
      end

      def fields
        {
          :key => @options[:key] || key,
          :acl => @options[:acl],
          "AWSAccessKeyId" => @options[:aws_access_key_id],
          :policy => policy,
          :signature => signature,
          :success_action_status => "201",
          'X-Requested-With' => 'xhr'
        }
      end

      def key
        @key ||= "uploads/#{DateTime.now.utc.strftime("%Y%m%dT%H%MZ")}_#{SecureRandom.hex}/${filename}"
      end

      def url
        "https://#{@options[:region]}.amazonaws.com/#{@options[:bucket]}/"
      end

      def policy
        Base64.encode64(policy_data.to_json).gsub("\n", "")
      end

      def policy_data
        {
          expiration: @options[:expiration],
          conditions: [
            ["starts-with", "$utf8", ""],
            ["starts-with", "$key", ""],
            ["starts-with", "$x-requested-with", ""],
            ["content-length-range", 0, @options[:max_file_size]],
            ["starts-with","$Content-Type",""],
            {bucket: @options[:bucket]},
            {acl: @options[:acl]},
            {success_action_status: "201"}
          ]
        }
      end

      def signature
        Base64.encode64(
          OpenSSL::HMAC.digest(
            OpenSSL::Digest::Digest.new('sha1'),
            @options[:aws_secret_access_key], policy
          )
        ).gsub("\n", "")
      end
    end
  end

  module SimpleUploadHelper
    def s3_uploader_hidden_fields(options = {}, &block)
      uploader = S3UploaderSimple.new(options)
      (uploader.fields).map do |name, value|
        hidden_field_tag(name, value, :class => "s3upload_hidden_fields")
      end.join.html_safe
    end

    def s3_uploader_field(options = {})
      uploader = S3UploaderSimple.new(options)
      file_field_tag(:file, uploader.field_options).html_safe
    end

    class S3UploaderSimple
      def initialize(options)
        @key_starts_with = options[:key_starts_with] || "uploads/"
        @options = options.reverse_merge(
          aws_access_key_id: S3DirectUpload.config.access_key_id,
          aws_secret_access_key: S3DirectUpload.config.secret_access_key,
          bucket: S3DirectUpload.config.bucket,
          region: S3DirectUpload.config.region || "s3",
          url: S3DirectUpload.config.url,
          ssl: true,
          acl: "public-read",
          expiration: 10.hours.from_now.utc.iso8601,
          max_file_size: 500.megabytes,
          callback_method: "POST",
          callback_param: "file",
          key_starts_with: @key_starts_with,
          key: key
        )
      end

      def form_options
        {
          method: "post",
          authenticity_token: false,
          multipart: true,
        }.merge(field_options)
      end

      def field_options
        form_data_options.merge(form_preset_options)
      end

      def form_data_options
        {
          data: {
              callback_url: @options[:callback_url],
              callback_method: @options[:callback_method],
              callback_param: @options[:callback_param]
          }.reverse_merge(@options[:data] || {})
        }
      end

      def form_preset_options
        {
          id: @options[:id],
          class: @options[:class],
        }
      end

      def fields
        {
          :key => @options[:key] || key,
          :acl => @options[:acl],
          "AWSAccessKeyId" => @options[:aws_access_key_id],
          :policy => policy,
          :signature => signature,
          :success_action_status => "201",
          'X-Requested-With' => 'xhr'
        }
      end

      def key
        @key ||= "#{@key_starts_with}{timestamp}-{unique_id}-#{SecureRandom.hex}/${filename}"
      end

      def url
        @options[:url] || "http#{@options[:ssl] ? 's' : ''}://#{@options[:region]}.amazonaws.com/#{@options[:bucket]}/"
      end

      def policy
        Base64.encode64(policy_data.to_json).gsub("\n", "")
      end

      def policy_data
        {
          expiration: @options[:expiration],
          conditions: [
            ["starts-with", "$key", @options[:key_starts_with]],
            ["starts-with", "$x-requested-with", ""],
            ["content-length-range", 0, @options[:max_file_size]],
            ["starts-with","$Content-Type",""],
            {bucket: @options[:bucket]},
            {acl: @options[:acl]},
            {success_action_status: "201"}
          ] + (@options[:conditions] || [])
        }
      end

      def signature
        Base64.encode64(
          OpenSSL::HMAC.digest(
            OpenSSL::Digest::Digest.new('sha1'),
            @options[:aws_secret_access_key], policy
          )
        ).gsub("\n", "")
      end
    end
  end
end