/*
* ===========================================================================
* (c) Copyright IBM Corp. 2017 All Rights Reserved
* ===========================================================================
 * 
 * This code is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 2 only, as
 * published by the Free Software Foundation.  
 *
 * This code is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * version 2 for more details (a copy is included in the LICENSE file that
 * accompanied this code).
 *
 * You should have received a copy of the GNU General Public License version
 * 2 along with this work; if not, see <http://www.gnu.org/licenses/>.
 * 
 * ===========================================================================
*/

package java.io;

import java.lang.ref.ReferenceQueue;
import java.lang.ref.WeakReference;
import java.security.AccessController;
import java.security.PrivilegedAction;
import java.util.Objects;
import java.util.concurrent.ConcurrentHashMap;
/* ClassCache is Primarily responsible for Caching the results of the className lookups and hence to avoid 
 * multiple Lookup for same Class Instance.
 * ClassCache provides a ConcurrentHash based ClassCache which is looked up prior to calling the class.forName
 *  Method resolveClass() from ObjectInputStream uses this Cache.
 *  
 *  Caching is done only when the actually used loader for a Class is one of the Sytem loaders (ie) App Class Loader,
 *  System Extension loader and BootStrap loader
 *   
 */
final class ClassCache {
/* Main Cache for storing the Class.forName results Here Key used would be CacheKey */
    private final ConcurrentHashMap<Key,Object> cache =
        new ConcurrentHashMap<Key,Object>(); 
/* Initiating Loader to CacheKey mapping in the Cache used by Reaper thread for removal on stale Loaders */
    private final ConcurrentHashMap<LoaderRef,CacheKey> loaderKeys =
        new ConcurrentHashMap<LoaderRef,CacheKey>();
 /* Keeps a link of Actual System Loader used to Initiating Loader mapping */
    private final ConcurrentHashMap<LoaderRef,LoaderRef> canonicalLoaderRefs =
        new ConcurrentHashMap<LoaderRef,LoaderRef>();
 /* Reference Queue registered for notification on stale Loaders */
    private final ReferenceQueue<Object> staleLoaderRefs =
        new ReferenceQueue<Object>();
/*
 * Constructor Populates Canonical Loader Refs with System Loader Entries and initializes the reaper thread which
 * monitors the ReferenceQueue for stale loaders
 */
    
    public ClassCache() {
        ClassLoader loader = ClassLoader.getSystemClassLoader(); 
        while (loader != null) {
            setCanonicalSystemLoaderRef(loader);
            loader = loader.getParent();
        }
        setCanonicalSystemLoaderRef(null);
        AccessController.doPrivileged(
                new CreateReaperAction(this, staleLoaderRefs)).start();
    }
    /*
     * sets Canonical Loader reference for the loader
     */

    private void setCanonicalSystemLoaderRef(ClassLoader loader) {
        LoaderRef newKey = new LoaderRef(loader, staleLoaderRefs, true);
        assert (canonicalLoaderRefs.put(newKey, newKey) == null);
    }
    
    /*
     * get Canonical Loader reference for the loader
     */


    LoaderRef getCanonicalLoaderRef(Object loaderObj) {
        LoaderRef newKey = new LoaderRef(loaderObj, staleLoaderRefs);

        LoaderRef key = canonicalLoaderRefs.get(newKey);
        if (key == null) {
            key = canonicalLoaderRefs.putIfAbsent(newKey, newKey);
            if (key == null) {
                return newKey;
            }
        }

        newKey.clear();
        return key;
    }
/*
 * Remove unused LoaderKey, and initiates corresponding CacheKey entry the main Cache
 */
    void removeStaleRef(LoaderRef loaderRef) {
        canonicalLoaderRefs.remove(loaderRef);
        CacheKey key = loaderKeys.remove(loaderRef);
        while (key != null) {
            cache.remove(key);
            key = key.next;
        }
    }

/*
 * Identifies if the loader used to load is one of the system loaders, 
 * if so updates the cache and the LoaderKey, and also a StaleLoaderReference for the initiating LoaderObject
 * via LoaderRef Constructor
 */
    void update(CacheKey key, Class<?> result) {
        Object resultLoaderObj =
            LoaderRef.getLoaderObj(result.getClassLoader());
        if (getCanonicalLoaderRef(resultLoaderObj).isSystem == false) {
            return;
        }

        Object oldValue = cache.replace(key, result);
        assert (oldValue instanceof FutureValue) :
            ("Value replaced is of type '" + oldValue.getClass().getName() +
             "', not of type '" + FutureValue.class.getName() + "'.");

        LoaderRef loaderRef = key.loaderRef;
        if (loaderRef.isSystem == false) {
            key.next = loaderKeys.get(loaderRef);
            if (key.next == null) {
                key.next = loaderKeys.putIfAbsent(loaderRef, key);
                if (key.next == null) return;
            }
            while (!loaderKeys.replace(loaderRef, key.next, key)) {
                key.next = loaderKeys.get(loaderRef);
            }
        }
    }
/*
 * Creates a New Entry in the Cache 
 */
    private Object createEntry(CacheKey key) {
        FutureValue newValue = new FutureValue(key, this); //Does actual call to class.forName as required.
        Object value = cache.putIfAbsent(key, newValue);
        if (value == null) value = newValue;
        return value;
    }
/*
 * This is the entry point in to the cache from ObjectInputStream. First Lookup is done based on the className and Loader 
 */
    public Class<?> get(String className, ClassLoader loader)
        throws ClassNotFoundException {
        LookupKey key = new LookupKey(className, loader, this);
        Object value = cache.get(key);
        if (value == null) {
        	value = createEntry(key.createCacheKey());
        }

        if (value instanceof FutureValue) {
        	
            return ((FutureValue)value).get();
        }

        return (Class<?>)value;
    }
    
    /*
     * FutureValue implements Future Mechanics that is required for addressing  contention issues in the HashMap
     */

    private static final class FutureValue {
        private final CacheKey key;
        private final LoaderRef loaderRef;
        private final ClassCache cache;
        private Class<?> value = null;

        FutureValue(CacheKey key, ClassCache cache) {
            this.key = key;
            this.loaderRef = key.loaderRef;
            this.cache = cache;
        }

        /*
         * tries to get the value from Cache, if not available tries to do get class.forName with active loader
         * and replace the entry in the cache as required
         */
        Class<?> get() throws ClassNotFoundException {
            synchronized (this) {
                if (value != null) return value;
                value = Class.forName(key.className, false,
                        loaderRef.getActiveLoader());
            }
            if (value != null) {
                cache.update(key, value);
            }

            return value;
        }
    }

    private static final class CreateReaperAction
            implements PrivilegedAction<Thread> {
        private final ClassCache cache;
        private final ReferenceQueue<Object> queue;

        CreateReaperAction(ClassCache cache, ReferenceQueue<Object> queue) {
            this.cache = cache;
            this.queue = queue;
        }

        public Thread run() {
            return new Reaper(cache, queue);
        }
    }

    private static final class Reaper extends Thread {
        private final WeakReference<ClassCache> cacheRef;
        private final ReferenceQueue<Object> queue;

        Reaper(ClassCache cache, ReferenceQueue<Object> queue) {
            super("ClassCache Reaper");
            this.queue = queue;
            cacheRef = new WeakReference<ClassCache>(cache, queue);
            setDaemon(true);
            setContextClassLoader(null);
        }
/*
 * Blocks on remove() on queur reference and calls processStaleRef() when any loader is removed.(non-Javadoc)
 * @see java.lang.Thread#run()
 */
        public void run() {
            Object staleRef = null;
            do {
                try {
                    staleRef = queue.remove();
                    if (staleRef == cacheRef) break;

                    processStaleRef((LoaderRef)staleRef);
                } catch (InterruptedException e) { }
            } while (true);
        }

        private void processStaleRef(LoaderRef staleRef) {
            ClassCache cache = cacheRef.get();
            if (cache == null) return;

            cache.removeStaleRef(staleRef);
        }
    }
    
    /*
     * The use of the loaderRefs map is to  allow efficient processing
     *  of one Weak Reference for each stale ClassLoader, rather than one WR for each entry in the cache. 
     *   
     * CacheKey as well as Lookup Key will be refering to this LoaderRef.
     *
     * Initiating Class Loaders needs to be referred for both lookup and Caching,so for performance reasons
     * a LoaderRef is maintained which would be used by both LookupKey and CachingKey
     * (ie) LookupKey will actually store the LoaderObj, but it will be canonically refered via a loaderRed
     * by the caching Key
     * LoaderKey has LoaderRef Objects as well and is used to Link the Initiating Loader with the actual cache Entries 
     * which is used to remove Stale reference entries.
     */

    private static class LoaderRef extends WeakReference<Object> {
        private static final String NULL_LOADER = new String("");
        private final int hashcode;
        public final boolean isSystem;

        static Object getLoaderObj(ClassLoader loader) {
            return ((loader == null) ? NULL_LOADER : loader);
        }

        LoaderRef(Object loaderObj, ReferenceQueue<Object> queue) {
            this(false, Objects.requireNonNull(loaderObj), queue);
        }

        LoaderRef(ClassLoader loader, ReferenceQueue<Object> queue,
                boolean isSystem) {
            this(isSystem, getLoaderObj(loader), queue);
        }
        
        /*
         * Creates a new weak reference that refers to the given object and is registered with the given queue. 
         */

        private LoaderRef(boolean isSystem, Object loaderObj,
                ReferenceQueue<Object> queue) {
            super(loaderObj, queue);
            String loaderClassName = ((loaderObj == NULL_LOADER) ?
                    NULL_LOADER : loaderObj.getClass().getName());
            hashcode = (loaderClassName.hashCode() +
                    System.identityHashCode(loaderObj));
            this.isSystem = isSystem;
        }

        public final boolean equals(Object o) {
            if (this == o) return true;
            if (!(o instanceof LoaderRef)) return false;

            Object loader = get();
            return ((loader != null) && (loader == ((LoaderRef)o).get()));
        }

        public final int hashCode() {
            return hashcode;
        }

        ClassLoader getActiveLoader() {
            Object loaderObj = Objects.requireNonNull(get());
            return ((loaderObj == NULL_LOADER) ? null : (ClassLoader)loaderObj);
        }
    }
    /*
     * For better clarity and to avoid multiple lookups to the cache. Key is implemented to have
     * one abstract key to final sub classes which serve specific purpose
     * LookupKey - This is a short lived key, not part of any hashmap and stores the strong reference to 
     * loaderobject
     * CachingKey - uses the same hash as LookupKey and has a means to be generated from LookupKey and has reference 
     * to the Loaderobj via a weakreference.
     */

    private static abstract class Key {
        public final String className;
        protected final int hashcode;

        protected Key(String className, int hashcode) {
            this.className = className;
            this.hashcode = hashcode;
        }

        abstract Object getLoaderObj();

        public final boolean equals(Object o) {
            if (this == o) return true;
            if (!(o instanceof Key)) return false;

            Key k = (Key)o;
            Object loaderObj = getLoaderObj();
            return (className.equals(k.className) &&
                    (loaderObj != null) && (loaderObj == k.getLoaderObj()));
        }

        public final int hashCode() {
            return hashcode;
        }
    }
    /*
     * Lookup Key hash code is framed using loadername hash + loader's system identity hashcode.  This 
     * is same as the hashcode maintained in CacheKey
     */

    private static final class LookupKey extends Key {
        private final Object loaderObj;
        private final ClassCache cache;

        private static int hashCode(String className, ClassLoader loader) {
            int hashcode = className.hashCode();
            if (loader != null) {
                hashcode += (loader.getClass().getName().hashCode() +
                        System.identityHashCode(loader));
            }
            return hashcode;
        }

        public LookupKey(String className, ClassLoader loader,
                ClassCache cache) {
            super(Objects.requireNonNull(className),
                    hashCode(className, loader));
            loaderObj = LoaderRef.getLoaderObj(loader);
            this.cache = cache;
        }

        Object getLoaderObj() {
            return loaderObj;
        }

        CacheKey createCacheKey() {
            return new CacheKey(className, hashcode,
                    cache.getCanonicalLoaderRef(loaderObj));
        }
    }

    /*
     * CacheKey is the actual key that is stored in the cache, and it stores the weakreference 
     * of the Initiating loader object via loaderRef
     * 
     */
    private static final class CacheKey extends Key {
        public final LoaderRef loaderRef;
        public CacheKey next = null;

        CacheKey(String className, int hashcode, LoaderRef loaderRef) {
            super(className, hashcode);
            this.loaderRef = loaderRef;
        }

        Object getLoaderObj() {
            return loaderRef.get();
        }
    }
}
