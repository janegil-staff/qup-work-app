// /qup-work-app/src/lib/categories.js
// Categories rarely change, so they're fetched once per app session.
import { useEffect, useState } from 'react';
import { api } from '@/lib/api';

let cache = null;

export function loadCategories() {
  cache ??= api('/categories', { auth: false })
    .then((res) => res.categories)
    .catch((err) => {
      cache = null; // try again next time
      throw err;
    });
  return cache;
}

// { all, roots, childrenOf(id) }
export function useCategories() {
  const [all, setAll] = useState([]);

  useEffect(() => {
    let alive = true;
    loadCategories()
      .then((list) => alive && setAll(list))
      .catch(() => {});
    return () => {
      alive = false;
    };
  }, []);

  const roots = all.filter((c) => !c.parent);
  const childrenOf = (id) => all.filter((c) => c.parent === id);
  return { all, roots, childrenOf };
}
