const resourceName = window.GetParentResourceName ? window.GetParentResourceName() : 'void-prison';

let inmateData = [];
let activeInmate = null;

// ============================================================================
// SYSTEM TIME CLOCK
// ============================================================================
function updateClock() {
    const timeDisplay = document.getElementById('current-time');
    const now = new Date();
    const hours = String(now.getHours()).padStart(2, '0');
    const minutes = String(now.getMinutes()).padStart(2, '0');
    timeDisplay.textContent = `${hours}:${minutes}`;
}
setInterval(updateClock, 1000);
updateClock();

// ============================================================================
// NUI EVENT LISTENER
// ============================================================================
window.addEventListener('message', function(event) {
    const data = event.data;
    if (data.action === "openTablet") {
        document.getElementById('tablet-container').classList.remove('tablet-closed');
        fetchInmateList();
    }
});

// ============================================================================
// CLOSE TABLET TRIGGERS
// ============================================================================
function closeTablet() {
    document.getElementById('tablet-container').classList.add('tablet-closed');
    fetch(`https://${resourceName}/closeTablet`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8'
        },
        body: JSON.stringify({})
    });
}

document.getElementById('close-tablet-btn').addEventListener('click', closeTablet);

// Close on Escape key press
window.addEventListener('keyup', function(e) {
    if (e.key === "Escape") {
        closeTablet();
    }
});

// ============================================================================
// API CALLS (NUI CALLBACKS)
// ============================================================================
function fetchInmateList() {
    fetch(`https://${resourceName}/getInmates`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8'
        },
        body: JSON.stringify({})
    })
    .then(res => res.json())
    .then(data => {
        inmateData = data;
        renderInmateList(inmateData);
    })
    .catch(err => {
        console.error("Failed to fetch inmate list:", err);
        // Fallback test data for offline dev preview if loaded in browser
        if (!window.invokeNative) {
            inmateData = [
                { citizenid: "CID3302", name: "Frank Martin", totalTime: 120, remainingTime: 45, reason: "Grand Theft Auto, Evasion of arrest, Reckless driving", online: true, jailedAt: "2026-06-01 18:30" },
                { citizenid: "CID8842", name: "Jimmy Hopkins", totalTime: 300, remainingTime: 280, reason: "Assault on Officer, Carrying unlicensed firearm, Trespassing", online: false, jailedAt: "2026-06-01 17:15" },
                { citizenid: "CID9921", name: "Trevor Philips", totalTime: 500, remainingTime: 15, reason: "Public intoxication, Chaos, Destruction of county property", online: true, jailedAt: "2026-06-01 12:00" }
            ];
            renderInmateList(inmateData);
        }
    });
}

function updateInmateSentence(citizenid, amount) {
    fetch(`https://${resourceName}/updateSentence`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8'
        },
        body: JSON.stringify({ citizenid, amount })
    }).then(() => {
        closeModal();
        setTimeout(fetchInmateList, 300); // refresh list
    });
}

function releaseInmateEarly(citizenid) {
    fetch(`https://${resourceName}/releaseInmate`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8'
        },
        body: JSON.stringify({ citizenid })
    }).then(() => {
        closeModal();
        setTimeout(fetchInmateList, 300); // refresh list
    });
}

// ============================================================================
// LIST RENDERING
// ============================================================================
function renderInmateList(inmates) {
    const grid = document.getElementById('inmate-grid');
    const noInmatesMsg = document.getElementById('no-inmates-message');
    grid.innerHTML = '';

    // Update stats counters
    document.getElementById('total-inmates-count').textContent = inmates.length;
    const onlineCount = inmates.filter(i => i.online).length;
    document.getElementById('online-inmates-count').textContent = onlineCount;

    if (inmates.length === 0) {
        noInmatesMsg.classList.remove('hidden');
        return;
    } else {
        noInmatesMsg.classList.add('hidden');
    }

    inmates.forEach(inmate => {
        const remaining = Math.max(0, inmate.remainingTime);
        const total = inmate.totalTime || 1;
        const progressPercentage = Math.min(100, Math.max(0, (remaining / total) * 100));

        const card = document.createElement('div');
        card.className = 'inmate-card';
        card.innerHTML = `
            <div class="card-header">
                <div class="card-title">
                    <h3>${inmate.name}</h3>
                    <p>CID: ${inmate.citizenid}</p>
                </div>
                <span class="status-badge ${inmate.online ? 'status-online' : 'status-offline'}">
                    <span class="status-dot ${inmate.online ? 'online-pulse' : ''}"></span>
                    ${inmate.online ? 'ONLINE' : 'OFFLINE'}
                </span>
            </div>
            <div class="card-reason">${inmate.reason || 'No sentencing record.'}</div>
            <div class="card-sentence">
                <div class="progress-header">
                    <span>Remaining Sentence</span>
                    <span><span class="highlight">${remaining}</span> / ${total} months</span>
                </div>
                <div class="progress-bar-bg">
                    <div class="progress-bar-fill" style="width: ${progressPercentage}%"></div>
                </div>
            </div>
        `;

        card.addEventListener('click', () => openModal(inmate));
        grid.appendChild(card);
    });
}

// ============================================================================
// SEARCH FILTERING
// ============================================================================
document.getElementById('search-input').addEventListener('input', function(e) {
    const query = e.target.value.toLowerCase();
    const filtered = inmateData.filter(inmate => {
        return inmate.name.toLowerCase().includes(query) ||
               inmate.citizenid.toLowerCase().includes(query) ||
               (inmate.reason && inmate.reason.toLowerCase().includes(query));
    });
    renderInmateList(filtered);
});

// ============================================================================
// MODAL CONTROLS
// ============================================================================
const modal = document.getElementById('action-modal');

function openModal(inmate) {
    activeInmate = inmate;
    
    document.getElementById('modal-inmate-name').textContent = inmate.name.toUpperCase();
    document.getElementById('modal-inmate-cid').textContent = inmate.citizenid;
    document.getElementById('modal-inmate-reason').textContent = inmate.reason || 'No sentencing record available.';
    document.getElementById('modal-total-sentence').textContent = inmate.totalTime + ' months';
    document.getElementById('modal-remaining-sentence').textContent = Math.max(0, inmate.remainingTime) + ' months';
    
    const statusBadge = document.getElementById('modal-inmate-status');
    statusBadge.textContent = inmate.online ? 'ONLINE' : 'OFFLINE';
    statusBadge.className = 'modal-status-badge'; // reset
    statusBadge.classList.add(inmate.online ? 'status-online' : 'status-offline');

    // Reset input
    document.getElementById('custom-adjust-amount').value = '';

    modal.classList.remove('hidden');
}

function closeModal() {
    modal.classList.add('hidden');
    activeInmate = null;
}

document.getElementById('close-modal-x').addEventListener('click', closeModal);
modal.addEventListener('click', function(e) {
    if (e.target === modal) closeModal();
});

// Sentence quick adjust button click handlers
document.querySelectorAll('.quick-adjust-buttons button').forEach(button => {
    button.addEventListener('click', function() {
        if (!activeInmate) return;
        const amount = parseInt(this.getAttribute('data-amount'));
        updateInmateSentence(activeInmate.citizenid, amount);
    });
});

// Custom adjust button handlers
document.getElementById('custom-adjust-add-btn').addEventListener('click', function() {
    if (!activeInmate) return;
    const val = parseInt(document.getElementById('custom-adjust-amount').value);
    if (!isNaN(val) && val > 0) {
        updateInmateSentence(activeInmate.citizenid, val);
    }
});

document.getElementById('custom-adjust-reduce-btn').addEventListener('click', function() {
    if (!activeInmate) return;
    const val = parseInt(document.getElementById('custom-adjust-amount').value);
    if (!isNaN(val) && val > 0) {
        updateInmateSentence(activeInmate.citizenid, -val);
    }
});

// Release inmate click handler (requires confirmation)
let releaseConfirmActive = false;
const releaseBtn = document.getElementById('release-inmate-btn');

releaseBtn.addEventListener('click', function() {
    if (!activeInmate) return;
    
    if (!releaseConfirmActive) {
        releaseConfirmActive = true;
        releaseBtn.textContent = "DOUBLE-CLICK TO CONFIRM RELEASE";
        releaseBtn.style.background = "#ff9100"; // change to warning color
        
        setTimeout(() => {
            releaseConfirmActive = false;
            releaseBtn.textContent = "RELEASE INMATE EARLY";
            releaseBtn.style.background = ""; // revert
        }, 3000);
    } else {
        releaseInmateEarly(activeInmate.citizenid);
        releaseConfirmActive = false;
        releaseBtn.textContent = "RELEASE INMATE EARLY";
        releaseBtn.style.background = "";
    }
});
