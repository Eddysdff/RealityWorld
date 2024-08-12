CHAT_TARGET = 'V5Ac3wuLeiI_cCfKMlUk8v8ztrzI9jpkvnO8AicCFik'

local json = require('json')
local sqlite3 = require('lsqlite3')

Llama = Llama or nil

LLAMA_TOKEN_PROCESS = 'pazXumQI-HPH7iFGfTC-4_7biSnqz_U67oFAGry5zUY'
LLAMA_TOKEN_DENOMINATION = 12
LLAMA_TOKEN_MULTIPLIER = 10 ^ LLAMA_TOKEN_DENOMINATION
LLAMA_ADVICE_PRICE_WHOLE_MIN = 5
LLAMA_ADVICE_PRICE_WHOLE_MIN_QUANTITY = LLAMA_ADVICE_PRICE_WHOLE_MIN * LLAMA_TOKEN_MULTIPLIER

LLAMA_GIVER_PROCESS = 'D5r-wBDfgo_Cx52uYoI8YiHp7QTqvpPbL8TtcbCoaXk'

AdvisorDb = AdvisorDb or sqlite3.open_memory()
AdvisorDbAdmin = AdvisorDbAdmin or require('DbAdmin').new(AdvisorDb)

SQLITE_TABLE_LLAMA_CREDIT = [[
  CREATE TABLE IF NOT EXISTS LlamaCredit (
    MessageId TEXT PRIMARY KEY,
    Timestamp INTEGER,
    Sender TEXT,
    Quantity INTEGER,
    AdviceTopic TEXT,
    Refunded INTEGER DEFAULT 0
  );
]]

function InitDb()
  AdvisorDb:exec(SQLITE_TABLE_LLAMA_CREDIT)
end

AdvisorInitialized = AdvisorInitialized or false
if (not AdvisorInitialized) then
  InitDb()
  Llama = require('@sam/Llama-Herder')
  Llama.getPrices()
  AdvisorInitialized = true
end

function ValidateLlamaQuantity(quantity)
  return quantity ~= nil
      and quantity >= LLAMA_ADVICE_PRICE_WHOLE_MIN_QUANTITY
      and quantity <= LLAMA_ADVICE_PRICE_WHOLE_MIN_QUANTITY
end

function ValidateAdviceTopic(topic)
  return topic ~= nil and type(topic) == 'string' and topic:len() > 0 and topic:len() <= 20
end

function FormatLlamaTokenAmount(amount)
  return string.format("%.1f", amount / LLAMA_TOKEN_MULTIPLIER)
end

-- 预设的旅行建议
local travelAdvice = {
  { name = "Paris", reason = "because you can wear a fancy beret, eat a baguette, and pretend you really speak French!" },
  { name = "Hawaii", reason = "because you can wear a Hawaiian shirt and a grass skirt, pretending it's official business attire." },
  { name = "Japan", reason = "because you can experience the most advanced toilets, which might be smarter than any device in your home!" },
  { name = "Australia", reason = "because you can hop around with kangaroos and pretend you're a true adventurer." },
  { name = "Iceland", reason = "because you can relax in the Blue Lagoon and imagine you're on another planet." },
}

function HandleAdvice(advice)
  print("HandleAdvice")
  print(advice)

  if advice == nil or advice:len() == 0 then
    Send({
      Target = CHAT_TARGET,
      Tags = {
        Action = 'ChatMessage',
        ['Author-Name'] = 'Travel Advisor',
      },
      Data = "I'm sorry, I couldn't come up with a travel suggestion right now. Maybe we should both take a vacation!",
    })
    return
  end

  Send({
    Target = CHAT_TARGET,
    Tags = {
      Action = 'ChatMessage',
      ['Author-Name'] = 'Travel Advisor',
    },
    Data = "Here's a travel suggestion for you: " .. advice,
  })
end

function DispatchAdviceMessage(adviceTopic)
  print("DispatchAdviceMessage")
  local advice = travelAdvice[math.random(#travelAdvice)]
  local message = "How about visiting " .. advice.name .. ", " .. advice.reason
  HandleAdvice(message)
end

Handlers.add(
  "CreditNoticeHandler",
  Handlers.utils.hasMatchingTag("Action", "Credit-Notice"),
  function(msg)
    if msg.From ~= LLAMA_TOKEN_PROCESS then
      return print("Credit Notice not from $LLAMA")
    end

    local sender = msg.Tags.Sender
    local messageId = msg.Id

    local quantity = tonumber(msg.Tags.Quantity)
    if not ValidateLlamaQuantity(quantity) then
      return print("Invalid quantity")
    end

    local adviceTopic = msg.Tags['X-AdviceTopic']
    if not ValidateAdviceTopic(adviceTopic) then
      return print("Invalid advice topic")
    end

    local stmt = AdvisorDb:prepare [[
      INSERT INTO LlamaCredit
      (MessageId, Timestamp, Sender, Quantity, AdviceTopic)
      VALUES (?, ?, ?, ?, ?)
    ]]
    stmt:bind_values(messageId, msg.Timestamp, sender, quantity, adviceTopic)
    stmt:step()
    stmt:finalize()

    Send({
      Target = LLAMA_TOKEN_PROCESS,
      Tags = {
        Action = 'Transfer',
        Recipient = LLAMA_GIVER_PROCESS,
        Quantity = msg.Tags.Quantity,
      },
    })

    Send({
      Target = CHAT_TARGET,
      Tags = {
        Action = 'ChatMessage',
        ['Author-Name'] = 'Travel Advisor',
      },
      Data = "Thanks for your interest in travel advice! Let me check my 'Ultimate Travel Guide' for a moment...",
    })

    DispatchAdviceMessage(adviceTopic)
  end
)

function AdviceSchemaTags()
  return [[
{
"type": "object",
"required": [
  "Action",
  "Recipient",
  "Quantity",
  "X-AdviceTopic"
],
"properties": {
  "Action": {
    "type": "string",
    "const": "Transfer"
  },
  "Recipient": {
    "type": "string",
    "const": "]] .. ao.id .. [["
  },
  "Quantity": {
    "type": "number",
    "default": ]] .. LLAMA_ADVICE_PRICE_WHOLE_MIN .. [[,
    "minimum": ]] .. LLAMA_ADVICE_PRICE_WHOLE_MIN .. [[,
    "maximum": ]] .. LLAMA_ADVICE_PRICE_WHOLE_MIN .. [[,
    "title": "$LLAMA cost (]] .. LLAMA_ADVICE_PRICE_WHOLE_MIN .. [[)",
    "$comment": "]] .. LLAMA_TOKEN_MULTIPLIER .. [["
  },
  "X-AdviceTopic": {
    "type": "string",
    "minLength": 1,
    "maxLength": 20,
    "default": "Adventure",
    "title": "Topic for your travel advice.",
  }
}
}
]]
end

Handlers.add(
  'TokenBalanceResponse',
  function(msg)
    local fromToken = msg.From == LLAMA_TOKEN_PROCESS
    local hasBalance = msg.Tags.Balance ~= nil
    return fromToken and hasBalance
  end,
  function(msg)
    local account = msg.Tags.Account
    local balance = tonumber(msg.Tags.Balance)
    print('Account: ' .. account .. ', Balance: ' .. balance)

    if (balance >= (LLAMA_ADVICE_PRICE_WHOLE_MIN_QUANTITY)) then
      Send({
        Target = account,
        Tags = { Type = 'SchemaExternal' },
        Data = json.encode({
          GetTravelAdvice = {
            Target = LLAMA_TOKEN_PROCESS,
            Title = "Want some travel advice?",
            Description =
            "Feeling adventurous? Send me a little $LLAMA and I'll suggest an exciting destination just for you!",
            Schema = {
              Tags = json.decode(AdviceSchemaTags()),
            },
          },
        })
      })
    else
      Send({
        Target = account,
        Tags = { Type = 'SchemaExternal' },
        Data = json.encode({
          GetTravelAdvice = {
            Target = LLAMA_TOKEN_PROCESS,
            Title = "Want some travel advice?",
            Description = "Your $LLAMA balance is too low for a trip! Come back when you've saved up for a proper adventure.",
            Schema = nil,
          },
        })
      })
    end
  end
)

Handlers.add(
  'SchemaExternal',
  Handlers.utils.hasMatchingTag('Action', 'SchemaExternal'),
  function(msg)
    print('SchemaExternal')
    Send({
      Target = LLAMA_TOKEN_PROCESS,
      Tags = {
        Action = 'Balance',
        Recipient = msg.From,
      },
    })
  end
)

print("Travel Advisor script loaded successfully")

return "Travel Advisor script initialized"