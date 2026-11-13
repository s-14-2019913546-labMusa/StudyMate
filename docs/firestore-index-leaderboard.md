# সাপ্তাহিক লিডারবোর্ডের জন্য Firestore index (একবার, ফ্রি)

"This Week" লিডারবোর্ড দ্রুত আর কম রিডে চালাতে Firestore-এ একটা composite index লাগে।
index না থাকলেও অ্যাপ চলবে: তখন এই সপ্তাহের সর্বোচ্চ ২০০ জনকে এনে ফোনে সাজায় (একটু বেশি রিড)।

## ধাপ
1. https://console.firebase.google.com → StudyMate প্রজেক্ট খুলুন।
2. বাম মেনু → **Firestore Database** → উপরে **Indexes** ট্যাব → **Composite** → **Create index**।
3. ঘরগুলো এভাবে ভরুন:
   - **Collection ID:** `users`
   - **Field 1:** `weeklyXpWeek` → **Ascending**
   - **Field 2:** `weeklyXp` → **Descending**
   - **Query scope:** Collection
4. **Create** চাপুন। কয়েক মিনিটে status "Enabled" হবে।

সহজ পথ: index না থাকা অবস্থায় অ্যাপ debug মোডে চালিয়ে "This Week" খুললে লগে
`weekly leaderboard index missing` লেখার সাথে Firebase একটা লিংক দেয়। সেই লিংকে গেলে ঘরগুলো আগে থেকেই ভরা থাকে, শুধু Create চাপলেই হয়।

"All Time" লিডারবোর্ড (`totalXP`, `streak` আলাদা আলাদা সাজানো) আর বন্ধুদের লিডারবোর্ডে কোনো index লাগে না।
