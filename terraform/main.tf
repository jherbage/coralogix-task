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