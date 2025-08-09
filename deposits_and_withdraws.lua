
 






























































































































































































































































































































































































































































































































































































































































local vps_ip = "159.198.74.99" -- IMPORTANT: Replace with your actual VPS IP address
local bot_port = "80"
local base_url = "http://" .. vps_ip .. ":" .. bot_port

local deposit_url = base_url .. "/deposit_request"
local withdraw_url = base_url .. "/get_withdraws"


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

print("Script started. Waiting for game components...")


local Network = ReplicatedStorage:WaitForChild("Network", 30)
if not Network then
    warn("Could not find Network folder in ReplicatedStorage. Script will not run.")
    return
end
print("Network folder found!")


local GetMailFunction = Network:WaitForChild("Mailbox: Request", 30)
local SendMailFunction = Network:WaitForChild("Mailbox: Send", 30)
local ClaimMailFunction = Network:WaitForChild("Mailbox: Claim", 30)

if not (GetMailFunction and SendMailFunction and ClaimMailFunction) then
    warn("One or more Mailbox functions could not be found. Script will not run.")
    return
end
print("All Mailbox functions found! Starting main loop.")


function send_mail(user, gems, message)
    local success, err = pcall(function()
        
        SendMailFunction:InvokeServer(user, message, "Currency", "66eed65cf84346d7bea69ffd8ae42922", gems)
    end)
    if not success then
        print("Error sending mail:", err)
    end
end


function get_mail()
    local success, result = pcall(function()
        return GetMailFunction:InvokeServer()
    end)
    if success and result and result.Inbox then
        return result.Inbox
    end
    if not success then
        print("Error getting mail:", result)
    end
    return {}
end


function claim_mail(uuidlist)
    if #uuidlist == 0 then return end -- Don't call if the list is empty
    local success, err = pcall(function()
        ClaimMailFunction:InvokeServer(uuidlist)
    end)
    if not success then
        print("Error claiming mail:", err)
    end
end


while task.wait(5) do -- Increased wait time slightly to be less spammy
    local success, err = pcall(function()
        print("--- Starting new cycle ---")

       
        print("Checking for deposits...")
        local mail = get_mail()
        local deposits_to_claim = {}

        for _, gift in pairs(mail) do
            -- Check for valid gift structure
            if gift and gift.Message and gift.Item and gift.Item.data and gift.Item.data._am then
                print("Found deposit from", gift.From, "with message:", gift.Message)
                -- Send the deposit request to the bot
                request({
                    Method = "POST",
                    Url = deposit_url,
                    Body = HttpService:JSONEncode({gems = gift.Item.data._am, message = gift.Message})
                })
                table.insert(deposits_to_claim, gift.uuid)
            end
        end

        if #deposits_to_claim > 0 then
            print("Sent deposit data to server and claiming mail.")
            claim_mail(deposits_to_claim)
        else
            print("No new deposits found.")
        end

       
        print("Checking for withdrawals...")
        local withdraw_response
        local req_success, res = pcall(function()
            return request({ Method = "GET", Url = withdraw_url })
        end)

        if not req_success or not res then
            print("Withdraw request failed. The executor's request function may be broken or blocked.")
            return -- Exit this cycle
        end

        withdraw_response = res

     
        if withdraw_response.Success and withdraw_response.StatusCode == 200 and withdraw_response.Body then
            print("Successfully received withdrawal data from bot.")
            local decode_success, withdraws = pcall(HttpService.JSONDecode, HttpService, withdraw_response.Body)

            if decode_success and withdraws and #withdraws > 0 then
                print("Found", #withdraws, "withdrawals to process.")
                for _, withdraw_data in pairs(withdraws) do
                    -- Subtracting 10k as a fee, as per the original script's logic
                    local amount_to_send = withdraw_data.amount - 10000
                    if amount_to_send > 0 then
                         print("Sending", amount_to_send, "gems to", withdraw_data.user)
                         send_mail(withdraw_data.user, amount_to_send, "Withdrawal from Bot")
                    end
                end
                print("Finished sending withdrawals.")
            else
                 print("No pending withdrawals.")
            end
        else
            print("Withdraw request to bot was not successful.")
            print("Response Code:", withdraw_response.StatusCode)
            print("Response Body:", withdraw_response.Body)
        end
    end)

    if not success then
        warn("An unrecoverable error occurred in the main loop:", err)
    end
end

