// Global variables
let contacts = [];
let contracts = [];
let currentContactIndex = -1;
let currentActionContractId = null;
let reputation = { level: 'Street Runner', points: 0 };

// Initialize when document is ready
$(document).ready(function() {
    // Listen for NUI messages
    window.addEventListener('message', function(event) {
        var data = event.data;
        
        switch (data.action) {
            case 'open':
                openPhone(data);
                break;
            case 'close':
                closePhone();
                break;
            case 'new_message':
                receiveMessage(data.contactIndex, data.message);
                break;
            case 'decrypt_message':
                decryptMessage(data.contactIndex, data.messageIndex, data.decryptTime);
                break;
            case 'self_destruct_complete':
                handleSelfDestruct(data.contactIndex, data.message);
                break;
        }
    });
    
    // Tab switching
    $('.tab').on('click', function() {
        const tabId = $(this).data('tab');
        $('.tab').removeClass('active');
        $(this).addClass('active');
        $('.tab-content').hide();
        $(`#${tabId}-container`).show();
    });
    
    // Contact selection
    $(document).on('click', '.contact', function() {
        const index = $(this).data('index');
        openConversation(index);
    });
    
    // Back button
    $('#back-button').on('click', function() {
        $('#conversation').hide();
        $('#contact-list').show();
    });
    
    // Self-destruct button
    $('#self-destruct-button').on('click', function() {
        $('#confirmation-message').text('Are you sure you want to wipe all data? This will clear all contracts and messages.');
        $('#confirmation-modal').show();
        $('#confirm-yes').data('action', 'self-destruct');
    });
    
    // Contract actions
    $(document).on('click', '.accept-btn', function() {
        const contractId = $(this).closest('.contract-card').data('id');
        $('#confirmation-message').text('Accept this contract?');
        $('#confirmation-modal').show();
        $('#confirm-yes').data('action', 'accept-contract');
        currentActionContractId = contractId;
    });
    
    $(document).on('click', '.decline-btn', function() {
        const contractId = $(this).closest('.contract-card').data('id');
        $('#confirmation-message').text('Decline this contract?');
        $('#confirmation-modal').show();
        $('#confirm-yes').data('action', 'decline-contract');
        currentActionContractId = contractId;
    });
    
    // Confirmation modal buttons
    $('#confirm-yes').on('click', function() {
        const action = $(this).data('action');
        
        switch (action) {
            case 'self-destruct':
                sendData('self_destruct', {});
                break;
            case 'accept-contract':
                sendData('accept_contract', { contractId: currentActionContractId });
                break;
            case 'decline-contract':
                sendData('decline_contract', { contractId: currentActionContractId });
                break;
        }
        
        $('#confirmation-modal').hide();
        currentActionContractId = null;
    });
    
    $('#confirm-no').on('click', function() {
        $('#confirmation-modal').hide();
        currentActionContractId = null;
    });
});

// Open the phone UI
function openPhone(data) {
    // Store data
    contacts = data.contacts || [];
    contracts = data.contracts || [];
    reputation = data.reputation || { level: 'Street Runner', points: 0 };
    
    // Update reputation display
    $('#rep-value').text(reputation.points);
    $('#rep-level').text(reputation.level);
    
    // Populate contacts
    renderContacts();
    
    // Populate contracts
    renderContracts();
    
    // Show the phone with static effect
    $('#phone-container').fadeIn(300);
    $('#static-overlay').show().css('animation', 'static 2s infinite');
    
    setTimeout(function() {
        $('#static-overlay').css('animation', 'none').fadeOut(500);
    }, 1000);
}

// Close the phone UI
function closePhone() {
    $('#static-overlay').show().css('opacity', 0.2);
    
    setTimeout(function() {
        $('#phone-container').fadeOut(300, function() {
            $('#static-overlay').hide();
            // Reset view
            $('#conversation').hide();
            $('#contact-list').show();
            $('.tab[data-tab="messages"]').click();
        });
    }, 300);
}

// Render contact list
function renderContacts() {
    $('#contact-list').empty();
    
    contacts.forEach((contact, index) => {
        const lastMessage = contact.messages.length > 0 
            ? contact.messages[contact.messages.length - 1].content 
            : 'No messages';
        
        const lastMessageTime = contact.messages.length > 0 
            ? contact.messages[contact.messages.length - 1].time 
            : '';
        
        // Truncate message preview
        const previewText = lastMessage.length > 25 ? lastMessage.substring(0, 25) + '...' : lastMessage;
        
        const $contact = $(`
            <div class="contact" data-index="${index}">
                <div class="contact-name">${contact.name}</div>
                <div class="contact-preview">${previewText}</div>
                <div class="contact-time">${lastMessageTime}</div>
            </div>
        `);
        
        $('#contact-list').append($contact);
    });
}

// Render contracts list
function renderContracts() {
    $('#contracts-list').empty();
    
    if (contracts.length === 0) {
        $('#no-contracts').show();
        return;
    }
    
    $('#no-contracts').hide();
    
    contracts.forEach(contract => {
        const difficultyClass = `difficulty-${contract.difficulty}`;
        
        const $contract = $(`
            <div class="contract-card" data-id="${contract.id}">
                <div class="contract-difficulty ${difficultyClass}">
                    ${getDifficultyLabel(contract.difficulty)}
                </div>
                <div class="contract-details">
                    ${contract.isDecoy ? '[HIGH PAYMENT]' : ''}
                    Pickup: ${contract.pickup.label}
                    Dropoff: ${contract.dropoff.label}
                    Payment: $${contract.payment}
                    Time Limit: ${contract.timeLimit} minutes
                </div>
                <div class="contract-actions">
                    <button class="accept-btn">ACCEPT</button>
                    <button class="decline-btn">DECLINE</button>
                </div>
            </div>
        `);
        
        $('#contracts-list').append($contract);
    });
}

// Get readable difficulty label
function getDifficultyLabel(difficulty) {
    switch(difficulty) {
        case 'easy':
            return 'LOW RISK';
        case 'medium':
            return 'MEDIUM RISK';
        case 'hard':
            return 'HIGH RISK';
        default:
            return 'UNKNOWN RISK';
    }
}

// Open conversation with a contact
function openConversation(index) {
    if (index < 0 || index >= contacts.length) return;
    
    currentContactIndex = index;
    const contact = contacts[index];
    
    // Update header
    $('#contact-name').text(contact.name);
    
    // Populate messages
    $('#message-list').empty();
    
    contact.messages.forEach(message => {
        renderMessage(message);
    });
    
    // Show conversation view
    $('#contact-list').hide();
    $('#conversation').show();
    
    // Scroll to bottom
    const messageList = document.getElementById('message-list');
    messageList.scrollTop = messageList.scrollHeight;
}

// Render a message in the conversation
function renderMessage(message) {
    let messageClass = message.sender === 'me' ? 'me' : 'them';
    if (message.sender === 'system') messageClass = 'system';
    
    const $message = $(`
        <div class="message ${messageClass}" data-contractId="${message.contractId || ''}">
            <div class="message-content">${message.content}</div>
            <div class="message-time">${message.time}</div>
        </div>
    `);
    
    // Add encrypted class if needed
    if (!message.decrypted) {
        $message.find('.message-content').addClass('encrypted');
        $message.find('.message-content').text(generateRandomEncrypted(message.content.length));
    }
    
    $('#message-list').append($message);
    
    // Scroll to bottom
    const messageList = document.getElementById('message-list');
    messageList.scrollTop = messageList.scrollHeight;
}

// Generate random encrypted-looking text
function generateRandomEncrypted(length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()_+-=[]{}|;:,.<>?/~`';
    let result = '';
    for (let i = 0; i < length; i++) {
        result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return result;
}

// Receive a new message
function receiveMessage(contactIndex, message) {
    // Update our local contacts array
    if (contactIndex >= 0 && contactIndex < contacts.length) {
        contacts[contactIndex].messages.push(message);
        
        // If we're currently viewing this conversation, render the message
        if (currentContactIndex === contactIndex && $('#conversation').is(':visible')) {
            renderMessage(message);
        } else {
            // Otherwise update the contact list
            renderContacts();
        }
        
        // Show static effect
        $('#static-overlay').show().css('opacity', 0.05).css('animation', 'static 1s infinite');
        
        setTimeout(function() {
            $('#static-overlay').css('animation', 'none').fadeOut(500);
        }, 1000);
    }
}

// Decrypt a message with animation
function decryptMessage(contactIndex, messageIndex, decryptTime) {
    if (contactIndex >= 0 && contactIndex < contacts.length) {
        if (messageIndex >= 0 && messageIndex < contacts[contactIndex].messages.length) {
            // Only proceed if we're viewing this conversation
            if (currentContactIndex === contactIndex && $('#conversation').is(':visible')) {
                const $messages = $('#message-list .message');
                
                if (messageIndex < $messages.length) {
                    const $message = $($messages[messageIndex]);
                    const $content = $message.find('.message-content');
                    
                    // Add decrypting animation
                    $content.addClass('decrypting');
                    
                    // Set the original content after animation
                    setTimeout(function() {
                        $content.removeClass('encrypted decrypting');
                        $content.text(contacts[contactIndex].messages[messageIndex].content);
                    }, decryptTime * 1000);
                }
            }
            
            // Mark as decrypted in our data
            contacts[contactIndex].messages[messageIndex].decrypted = true;
        }
    }
}

// Handle self-destruct
function handleSelfDestruct(contactIndex, message) {
    // Clear all contracts
    contracts = [];
    renderContracts();
    
    // Add the self-destruct system message
    if (contactIndex >= 0 && contactIndex < contacts.length) {
        contacts[contactIndex].messages.push(message);
        
        // If we're viewing this conversation, render the message
        if (currentContactIndex === contactIndex && $('#conversation').is(':visible')) {
            renderMessage(message);
        }
    }
    
    // Show a static animation
    $('#static-overlay').show().css('opacity', 0.3).css('animation', 'static 0.5s infinite');
    
    setTimeout(function() {
        $('#static-overlay').css('opacity', 0.1);
        
        setTimeout(function() {
            $('#static-overlay').css('animation', 'none').fadeOut(500);
        }, 1000);
    }, 2000);
}

// Send data back to the game
function sendData(action, data) {
    $.post(`https://vein-blackmarket/${action}`, JSON.stringify(data));
}

// Close on escape key
document.onkeyup = function(data) {
    if (data.which == 27) { // ESC
        sendData('close_phone', {});
    }
}; 