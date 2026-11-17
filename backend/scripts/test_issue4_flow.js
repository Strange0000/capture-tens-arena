import { io } from "socket.io-client";

const BASE_URL = process.env.BASE_URL || "http://localhost:3000";

async function createPlayer(name) {
  const guestRes = await fetch(`${BASE_URL}/auth/guest`, { method: "POST" });
  const guestData = await guestRes.json();
  const token = guestData.token;

  const claimRes = await fetch(`${BASE_URL}/users/username/claim`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    body: JSON.stringify({ username: name })
  });
  const claimData = await claimRes.json();
  return { token: claimData.token || token, user: claimData.user || guestData.user };
}

async function addFriend(p1, p2) {
  const reqRes = await fetch(`${BASE_URL}/users/friends/request`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${p1.token}` },
    body: JSON.stringify({ userId: p2.user.id, username: p2.user.username })
  });
  const reqData = await reqRes.json();
  const friendId = reqData.friend?.id || reqData.friend?._id;

  const accRes = await fetch(`${BASE_URL}/users/friends/accept`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${p2.token}` },
    body: JSON.stringify({ friendId })
  });
  await accRes.json();
}

async function run() {
  console.log("=== ISSUE 4 TEST: FRIENDS IN CUSTOM & RANKED MATCHES ===");
  const randA = "Sumit_" + Math.floor(Math.random() * 8999 + 1000);
  const randB = "Friend_" + Math.floor(Math.random() * 8999 + 1000);

  console.log(`1. Creating two players: ${randA} & ${randB}...`);
  const p1 = await createPlayer(randA);
  const p2 = await createPlayer(randB);

  console.log("2. Adding each other as friends...");
  await addFriend(p1, p2);
  console.log("   Friends added successfully!");

  console.log("3. Connecting sockets for both players...");
  const s1 = io(BASE_URL, { transports: ["websocket"], auth: { token: p1.token }, forceNew: true });
  const s2 = io(BASE_URL, { transports: ["websocket"], auth: { token: p2.token }, forceNew: true });

  await Promise.all([
    new Promise(r => s1.on("connect", r)),
    new Promise(r => s2.on("connect", r)),
  ]);
  console.log("   Both sockets connected!");

  // PART A: PARTY & RANKED QUEUE TOGETHER
  console.log("\n--- TEST PART A: PARTY & RANKED QUEUE ---");
  console.log("4. P1 invites P2 to party...");
  const partyInviteReceived = new Promise(resolve => {
    s2.on("party:invited", data => {
      console.log("   P2 received party:invited from:", data.from, "partyId:", data.partyId);
      resolve(data);
    });
  });

  s1.emit("party:invite", { targetUserId: p2.user.id });
  const inviteData = await partyInviteReceived;

  console.log("5. P2 accepts party invite...");
  const p1PartyUpdated = new Promise(resolve => {
    s1.on("party:updated", data => {
      if (data.party && data.party.length === 2) {
        console.log("   P1 party updated with 2 members:", data.party.map(m => m.username));
        resolve(data);
      }
    });
  });

  s2.emit("party:accept", { partyId: inviteData.partyId });
  await p1PartyUpdated;
  console.log("   Party successfully formed!");

  console.log("6. Party leader (P1) queues Ranked with party...");
  const p1Queued = new Promise(resolve => s1.on("queue:joined", resolve));
  const p2Queued = new Promise(resolve => s2.on("queue:joined", resolve));

  s1.emit("queue:ranked", { mmr: 0 });
  await Promise.all([p1Queued, p2Queued]);
  console.log("   BOTH players received queue:joined! Duo queue active!");

  console.log("7. Cancelling ranked search...");
  const p2Cancelled = new Promise(resolve => s2.on("queue:cancelled", resolve));
  s1.emit("queue:cancel");
  await p2Cancelled;
  console.log("   Queue cancelled for both party members!");

  // Leave party
  s1.emit("party:leave");
  await new Promise(r => setTimeout(r, 500));

  // PART B: CUSTOM ROOM WITH FRIEND
  console.log("\n--- TEST PART B: CUSTOM ROOM WITH FRIEND ---");
  console.log("8. P1 creates private room...");
  const roomCreated = new Promise(resolve => {
    s1.on("room:created", data => {
      console.log("   Room created with code:", data.code);
      resolve(data.code);
    });
  });
  s1.emit("room:create");
  const roomCode = await roomCreated;

  console.log("9. P1 invites P2 directly to the private room (room:invite)...");
  const p2RoomInviteReceived = new Promise(resolve => {
    s2.on("room:invited", data => {
      console.log("   P2 received room:invited event! From:", data.from, "Code:", data.code);
      resolve(data);
    });
  });

  s1.emit("room:invite", { targetUserId: p2.user.id, code: roomCode });
  const inviteRoomData = await p2RoomInviteReceived;

  console.log("10. P2 joins private room using code from invite:", inviteRoomData.code);
  const p1RoomUpdated = new Promise(resolve => {
    s1.on("room:updated", data => {
      console.log("   P1 received room:updated -> player count:", data.playerCount, "players:", data.players.map(p => p.username));
      if (data.playerCount === 2) resolve(data);
    });
  });

  s2.emit("room:join", { code: inviteRoomData.code });
  await p1RoomUpdated;
  console.log("   Both players are in the Custom Room together!");

  console.log("11. Starting match with bots (2 humans + 2 bots)...");
  const p1MatchCreated = new Promise(resolve => s1.on("match:created", resolve));
  const p2MatchCreated = new Promise(resolve => s2.on("match:created", resolve));

  s1.emit("room:startWithBots", { code: roomCode });
  const [m1, m2] = await Promise.all([p1MatchCreated, p2MatchCreated]);
  console.log("   Both players received match:created with matchId:", m1.matchId, "mode:", m1.mode);

  // Clean up
  s1.emit("match:leave");
  s2.emit("match:leave");
  s1.disconnect();
  s2.disconnect();

  console.log("\n=== ALL ISSUE 4 FLOWS PASSED SUCCESSFULLY! ===");
  process.exit(0);
}

run().catch(err => {
  console.error("Test failed:", err);
  process.exit(1);
});
