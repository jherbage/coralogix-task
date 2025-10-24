terraform {
  required_providers {
    coralogix = {
      version = "~> 2.0"
      source  = "coralogix/coralogix"
    }
  }
}

provider "coralogix" {
  #api_key = "<add your api key here or add env variable CORALOGIX_API_KEY>"
  env = "eu2"
}

resource "coralogix_rules_group" "cart_logs" {
  name         = "Cart Logs"
  description  = "Cart Logs"
  applications = []
  subsystems   = ["cart"]
  severities   = []
  order        = 1

  rule_subgroups {
    rules {
      extract {
        name               = "UserId"
        source_field       = "text"
        regular_expression = "userId=(?P<userId>[a-f0-9\\-]+\\b)"
      }
    }
  }
}


resource "coralogix_rules_group" "fraud_logs" {
  name         = "Fraud Logs"
  description  = "Fraud Logs"
  applications = []
  subsystems   = ["fraud-detection"]
  severities   = []
  order        = 1

  rule_subgroups {
    rules {
      extract {
        name               = "OrderId"
        source_field       = "text"
        regular_expression = "orderId:\\s+(?P<orderId>[a-f0-9\\-]+\\b)"
      }
    }
  }
}

resource "coralogix_rules_group" "block_otel_value_logs" {
  name         = "block the values explosion"
  description  = ""
  applications = []
  subsystems   = ["coralogix-opentelemetry-collector","coralogix-opentelemetry-agent"]
  severities   = []
  order        = 1

  rule_subgroups {
    rules {
      block {
        name               = "Block values expressions"
        source_field       = "text"
        regular_expression = "one or more paths were modified to include their context prefix, please rewrite them accordingly"
      }
    }
  }
}

resource "coralogix_rules_group" "fix_payment_service_mapping" {
  name         = "Fix Mapping Issue Payment Service"
  description  = ""
  applications = []
  subsystems   = ["payment"]
  severities   = []
  order        = 1

  rule_subgroups {
    rules {
      replace {
        name               = "Replace service.name with service_name"
        description        = "{\"loyalty_level\":\"platinum\",\"hostname\":\"payment-d6b878974-gvqgk\",\"trace_id\":\"d77c7f1c88a204db001df5b7b86058ca\",\"scope\":{\"attributes\":{}},\"observedTimeUnixNano\":1757419380201402170,\"lastFourDigits\":\"1278\",\"trace_flags\":\"01\",\"pid\":17,\"resource\":{\"attributes\":{\"k8s.container.name\":\"payment\",\"k8s.namespace.name\":\"default\",\"k8s.pod.name\":\"payment-d6b878974-gvqgk\",\"k8s.container.restart_count\":\"0\",\"k8s.pod.uid\":\"988a9fd1-c49f-40b2-a168-07cf4817b0bf\",\"k8s.cluster.name\":\"se-demo\",\"cx.otel_integration.name\":\"coralogix-integration-helm\",\"host.name\":\"minikube\",\"os.type\":\"linux\",\"host.id\":\"8cea92daa17d43978a2c10bb0f33194e\",\"k8s.node.name\":\"minikube\",\"k8s.deployment.name\":\"payment\"}},\"span_id\":\"1be1ac6e7f5758b8\",\"msg\":\"Transaction complete.\",\"time\":1757419380046,\"service.name\":\"payment\",\"level\":\"info\",\"attributes\":{\"log.iostream\":\"stdout\",\"log.file.path\":\"/var/log/pods/default_payment-d6b878974-gvqgk_988a9fd1-c49f-40b2-a168-07cf4817b0bf/payment/0.log\",\"time\":\"2025-09-09T12:03:00.04810967Z\"},\"amount\":{\"units\":{\"low\":90,\"high\":0,\"unsigned\":false},\"nanos\":289999999,\"currencyCode\":\"USD\"},\"resourceSchemaUrl\":\"https://opentelemetry.io/schemas/1.6.1\",\"cardType\":\"visa\",\"timeUnixNano\":1757419380048109670,\"transactionId\":\"1e1ee7cc-555c-4e4e-8d92-181daa13bd04\"}"
        source_field       = "text"
        destination_field  = "text"
        regular_expression = "service.name\":"
        replacement_string = "service_name\":"
      }
    }
  }
}

resource "coralogix_events2metric" "logs2metric_example" {
  name        = "payment_example"
  description = ""
  logs_query  = {
    subsystems   = ["payment"]
    lucene       = ""
  }

  metric_fields = {
    payment_units = {
      source_field = "amount.units.low"
      aggregations = {
        max = {
          enable = false
        }
        min = {
          enable = false
        }
        avg = {
          enable = true
        }
      }
    }
  }
    metric_labels = {
      currency = "amount.currencyCode"
      card_type   = "cardType"
      loyalty_level   = "loyalty_level"
  }

  permutations = {
    limit = 20000
  }

}

resource "coralogix_alert" "example_alert" {
  name        = "demo alert example"
  description = "Example of metric_threshold alert from terraform"
  priority    = "P3"

  type_definition = {
    metric_threshold = {
        metric_filter = {
            promql = "sum(payment_units_cx_sum{loyalty_level=\"gold\"}[5m])"
        }
        rules = [{
            condition = {
                threshold    = 30000
                for_over_pct = 10
                of_the_last = "10m"
                condition_type = "MORE_THAN_OR_EQUALS"
            }
            override = {
                priority = "P2"
            }
        }]
        missing_values = {
            replace_with_zero = true
        }
    }
  }
}