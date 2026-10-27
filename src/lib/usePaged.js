// /qup-work-app/src/lib/usePaged.js
// Loads a paginated API list ({ data, page, pages, total }) with refresh + infinite scroll.
//   const list = usePaged('/jobs/feed?category=123');
//   <FlatList data={list.items} onEndReached={list.loadMore} ... />
// Changing the path (e.g. a new search) reloads from page 1.
import { useCallback, useEffect, useRef, useState } from 'react';
import { api, errorMessage } from '@/lib/api';

export function usePaged(path, { limit = 20, enabled = true } = {}) {
  const [items, setItems] = useState([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [pages, setPages] = useState(1);
  const [status, setStatus] = useState('loading'); // loading | ready | error
  const [error, setError] = useState(null);
  const [refreshing, setRefreshing] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const requestId = useRef(0);

  const fetchPage = useCallback(
    (p) => api(`${path}${path.includes('?') ? '&' : '?'}page=${p}&limit=${limit}`),
    [path, limit]
  );

  const load = useCallback(async () => {
    const id = ++requestId.current; // ignore answers to older searches
    try {
      const res = await fetchPage(1);
      if (id !== requestId.current) return;
      setItems(res.data);
      setTotal(res.total);
      setPages(res.pages);
      setPage(1);
      setError(null);
      setStatus('ready');
    } catch (err) {
      if (id !== requestId.current) return;
      setError(errorMessage(err));
      setStatus((s) => (s === 'loading' ? 'error' : s));
    }
  }, [fetchPage]);

  useEffect(() => {
    if (!enabled) return;
    setStatus('loading');
    load();
  }, [load, enabled]);

  const refresh = useCallback(async () => {
    setRefreshing(true);
    await load();
    setRefreshing(false);
  }, [load]);

  const loadMore = useCallback(async () => {
    if (loadingMore || status !== 'ready' || page >= pages) return;
    setLoadingMore(true);
    try {
      const res = await fetchPage(page + 1);
      setItems((prev) => [...prev, ...res.data.filter((n) => !prev.some((o) => o._id === n._id))]);
      setPage(page + 1);
      setPages(res.pages);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setLoadingMore(false);
    }
  }, [fetchPage, loadingMore, status, page, pages]);

  return { items, total, status, error, refreshing, loadingMore, refresh, loadMore, reload: load };
}

// Delays a fast-changing value (typing in a search field) until the user pauses
export function useDebounced(value, ms = 350) {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const t = setTimeout(() => setDebounced(value), ms);
    return () => clearTimeout(t);
  }, [value, ms]);
  return debounced;
}

// Builds "/path?a=1&b=2", skipping empty values
export function withQuery(path, params) {
  const qs = Object.entries(params)
    .filter(([, v]) => v !== undefined && v !== null && v !== '')
    .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
    .join('&');
  return qs ? `${path}?${qs}` : path;
}
